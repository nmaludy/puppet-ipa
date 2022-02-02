require 'puppet/provider/ipa'

Puppet::Type.type(:ipa_dns_zone).provide(:default, parent: Puppet::Provider::Ipa) do
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
      'method' => 'dnszone_find/1',
      'params' => [
        # args (positional arguments)
        [],
        # options (CLI flags / options)
        {
          'all' => true,
          # use raw here because otherwise some of the properties return these weird nested dictionaries
          # only downside is that some of the keys come back with weird cases
          # we'll fix this later
          'raw' => true,
        },
      ],
    }
    response_body = api_post('/session/json', body: body, json_parse: true)
    dnszone_list = response_body['result']['result']
    Puppet.debug("Got DNS Zone list: #{dnszone_list}")

    instance_hash = {}
    dnszone_list.each do |dnszone|
      # --raw returns stuff in weird case formats
      # to prevent forward compatability problems we downcase everything before we pull it out
      dnszone.transform_keys!(&:downcase)
      instance = {
        ensure: :present,
        name: get_ldap_attribute(dnszone, 'idnsname'),
      }
      # optional properties
      instance[:allow_dynamic_update] = get_ldap_attribute_boolean(dnszone, 'idnsallowdynupdate') if dnszone['idnsallowdynupdate']
      instance[:allow_sync_ptr] = get_ldap_attribute_boolean(dnszone, 'idnsallowsyncptr') if dnszone['idnsallowsyncptr']

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
        'method' => 'dnszone_del/1',
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
                 'dnszone_add/1'
               else
                 # if the group was present then we need to modify
                 'dnszone_mod/1'
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
      unless resource[:allow_dynamic_update].nil?
        body['params'][1]['idnsallowdynupdate'] = resource[:allow_dynamic_update] ? 'TRUE' : 'FALSE'
      end
      unless resource[:allow_sync_ptr].nil?
        body['params'][1]['idnsallowsyncptr'] = resource[:allow_sync_ptr] ? 'TRUE' : 'FALSE'
      end
      api_post('/session/json', body: body)
    end
  end
end
