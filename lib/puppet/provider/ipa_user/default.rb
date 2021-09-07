require 'puppet/provider/ipa'

Puppet::Type.type(:ipa_user).provide(:default, parent: Puppet::Provider::Ipa) do
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
    # read all of the instances, once
    body = {
      'id' => 0,
      'method' => 'user_find/1',
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
    user_list = response_body['result']['result']
    Puppet.debug("Got user list: #{user_list}")

    instance_hash = {}
    user_list.each do |user|
      instance = {
        ensure: :present,
        name: get_ldap_attribute(user, 'uid'),
        # negate lock = enabled, yes use a symbol here
        enable: get_ldap_attribute_boolean(user, 'nsaccountlock') ? :false : :true,
        first_name: get_ldap_attribute(user, 'givenname'),
        last_name: get_ldap_attribute(user, 'sn'), # surname
      }
      instance[:sshpubkeys] = get_ldap_attribute(user, 'ipasshpubkey') if user['ipasshpubkey']
      instance[:login_shell] = get_ldap_attribute(user, 'loginshell') if user['loginshell']
      instance[:mail] = get_ldap_attribute(user, 'mail') if user['mail']
      instance[:job_title] = get_ldap_attribute(user, 'title') if user['title']

      # save all LDAP attributes and we'll filter later
      instance[:ldap_attributes] = {}
      user.each do |attr_key, _attr_value|
        instance[:ldap_attributes][attr_key] = get_ldap_attribute(user, attr_key)
      end
      instance_hash[instance[:name]] = instance
    end
    Puppet.debug("Returning user instances: #{instance_hash}")
    instance_hash
  end

  def read_instance(use_cache: true)
    instances_hash = use_cache ? cached_all_instances : read_all_instances
    if instances_hash.key?(resource[:name])
      instance = instances_hash[resource[:name]]
      # special handling for custom ldap attributes
      if resource[:ldap_attributes]
        # only keep the LDAP attributes in the instance that are specified on the resource
        instance[:ldap_attributes].select! do |attr_key, _attr_value|
          resource[:ldap_attributes].key?(attr_key)
        end
      else
        # resource didn't have ldap_attributes, so delete it
        instance[:ldap_attributes] = {}
      end
      instance
    else
      { ensure: :absent, name: resource[:name] }
    end
  end

  # this method should check resource[:ensure]
  #  if it is :present this method should create/update the instance using the values
  #  in resource[:xxx] (these are the desired state values)
  #  else if it is :absent this method should delete the instance
  #
  #  if you want to have access to the values before they were changed you can use
  #  cached_instance[:xxx] to compare against (that's why it exists)
  def flush_instance
    case resource[:ensure]
    when :absent
      body = {
        'id' => 0,
        'method' => 'user_del/1',
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
                 # if the user was absent, we need to add
                 'user_add/1'
               else
                 # if the user was present then we need to modify
                 'user_mod/1'
               end
      body = {
        'id' => 0,
        'method' => method,
        'params' => [
          # args (positional arguments)
          [resource[:name]],
          # options (CLI flags / options)
          {
            'givenname' => resource[:first_name],
            'sn' => resource[:last_name],
          },
        ],
      }

      # the user doesn't exist exist. only set the password on add/create
      if cached_instance[:ensure] == :absent
        body['params'][1]['userpassword'] = resource[:initial_password]
      end

      # negate enable = lock
      # yes, use a symbol here
      body['params'][1]['nsaccountlock'] = resource[:enable] == :false unless resource[:enable].nil?
      body['params'][1]['ipasshpubkey'] = resource[:sshpubkeys] if resource[:sshpubkeys]
      body['params'][1]['loginshell'] = resource[:login_shell] if resource[:login_shell]
      body['params'][1]['mail'] = resource[:mail] if resource[:mail]
      body['params'][1]['title'] = resource[:job_title] if resource[:job_title]

      # fill out additional LDAP attributes that the user is asking to sync
      if resource[:ldap_attributes]
        resource[:ldap_attributes].each do |attr_key, attr_value|
          body['params'][1][attr_key] = attr_value
        end
      end

      api_post('/session/json', body: body)
    end
  end
end
