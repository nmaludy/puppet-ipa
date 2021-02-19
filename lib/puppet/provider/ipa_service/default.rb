require 'puppet/provider/ipa'

Puppet::Type.type(:ipa_service).provide(:default, parent: Puppet::Provider::Ipa) do
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
      'method' => 'service_find/1',
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
    service_list = response_body['result']['result']
    Puppet.debug("Got Service list: #{service_list}")

    instance_hash = {}
    service_list.each do |service|
      instance = {
        ensure: :present,
        name: get_ldap_attribute(service, 'krbprincipalname'),
      }
      instance_hash[instance[:name]] = instance
    end
    Puppet.debug("Returning Service instances: #{instance_hash}")
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
        'method' => 'service_del/1',
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
                 'service_add/1'
               else
                 # if the group was present then we need to modify
                 'service_mod/1'
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
      api_post('/session/json', body: body)
    end
  end
end
