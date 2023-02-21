require 'puppet/provider/ipa'

Puppet::Type.type(:ipa_group).provide(:default, parent: Puppet::Provider::Ipa) do
  defaultfor kernel: 'Linux'

  # always need to define this in our implementation classes
  mk_resource_methods

  ##########################
  # private methods that we need to implement because we inherit from Puppet::Provider::Synapse

  # Read all instances of this type from the API, this will then be stored in a cache
  # We do it like this so that the first resource of this type takes the burden of
  # reading all of the data, but the following resources are all super fast because
  # they can use the global cache
  def read_all_instances
    # read all of the groups, once
    body = {
      'id' => 0,
      'method' => 'group_find/1',
      'params' => [
        # args (positional arguments)
        [],
        # options (CLI flags / options)
        {
          'all' => true,
        },
      ],
    }
    response_body = api_post('/session/json', body: body, json_parse: true)
    group_list = response_body['result']['result']
    Puppet.debug("Got group list: #{group_list}")

    instance_hash = {}
    group_list.each do |group|
      instance = {
        ensure: :present,
        name: get_ldap_attribute(group, 'cn'),
        description: get_ldap_attribute(group, 'description'),
        gid: get_ldap_attribute(group, 'gidnumber'),
        group_type: :non_posix,
      }

      # there nothing special on a group that determines if they are non_posix other
      # than the absence of the following two objectclass attributes that denote
      # either posix or external group types.
      # posix groups are denoted by an objectclass="posixgroup" attribute
      # external groups are denoted by an objectclass="ipaexternalgroup" attribute
      objectclasses = group['objectclass']
      objectclasses.each do |oc|
        if oc == 'posixgroup'
          instance[:group_type] = :posix
          break
        elsif oc == 'ipaexternalgroup'
          instance[:group_type] = :external
          break
        end
      end
      instance_hash[instance[:name]] = instance
    end
    Puppet.debug("Returning group instances: #{instance_hash}")
    instance_hash
  end

  # this method should check resource[:ensure]
  #  if it is :present this method should create/update the instance using the values
  #  in resource[:xxx] (these are the desired state values)
  #  else if it is :absent this method should delete the instance
  #
  #  if you want to have access to the values before they were changed you can use
  #  cached_instance[:xxx] to compare against (that's why it exists)
  def flush_instance
    # write a single instance at a time
    # we can't bulk write because instances may be written in different orders depending
    # on their relationships defined in PuppetDSL
    case resource[:ensure]
    when :absent
      body = {
        'id' => 0,
        'method' => 'group_del/1',
        'params' => [
          # args (positional arguments)
          [resource[:name]],
          # options (CLI flags / options)
          {},
        ],
      }
      api_post('/session/json', body: body)
    when :present
      method = if cached_instance[:ensure] == :absent
                 # if the group was absent, we need to add
                 'group_add/1'
               else
                 # if the group was present then we need to modify
                 'group_mod/1'
               end
      body = {
        'id' => 0,
        'method' => method,
        'params' => [
          # args (positional arguments)
          [resource[:name]],
          # options (CLI flags / options)
          {},
        ],
      }
      body['params'][1]['description'] = resource[:description] if resource[:description]
      body['params'][1]['gidnumber'] = resource[:gid] if resource[:gid]
      # can only set group "type" when adding the group
      if cached_instance[:ensure] == :absent
        if resource[:group_type] == :non_posix
          body['params'][1]['nonposix'] = true
        elsif resource[:group_type] == :external
          body['params'][1]['external'] = true
        end
        # default is posix type, no flags need to be set
      end

      api_post('/session/json', body: body)
    end
  end
end
