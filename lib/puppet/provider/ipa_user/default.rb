require File.expand_path(File.join(File.dirname(__FILE__), '..', 'ipa'))

Puppet::Type.type(:ipa_user).provide(:default, parent: Puppet::Provider::Ipa) do
  defaultfor kernel: 'Linux'

  commands ipa: 'ipa'

  # always need to define this in our implementation classes
  mk_resource_methods

  ##########################
  # private methods that we need to implement because we inherit from Puppet::Provider::Synapse

  # this method should retrieve an instance and return it as a hash
  # note: we explicitly do NOT cache within this method because we want to be
  #       able to call it both in initialize() and in flush() and return the current
  #       state of the resource from the API each time
  def read_instance
    body = {
      'id' => 0,
      'method' => 'user_find/1',
      'params' => [
        # args (positional arguments)
        [resource[:name]],
        # options (CLI flags / options)
        {
          'all' => true,
        },
      ],
    }
    response_body = api_post('/session/json', body: body, json_parse: true)
    user_list = response_body['result']['result']
    user = user_list.find { |u| u['uid'][0] == resource[:name] }

    instance = nil
    if user.nil?
      instance = { ensure: :absent, name: resource[:name] }
    else
      instance = {
        ensure: :present,
        name: user['uid'][0],
        first_name: user['givenname'][0],
        last_name: user['sn'][0], # surname
      }
      instance[:sshpubkeys] = user['ipasshpubkey'] if user['ipasshpubkey']
    end
    Puppet.debug("Returning user instance: #{instance}")
    instance
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

      body['params'][1]['ipasshpubkey'] = resource[:sshpubkeys] if resource[:sshpubkeys]
      api_post('/session/json', body: body)
    end
  end
end
