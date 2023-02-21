require 'puppet/provider/ipa'

Puppet::Type.type(:ipa_group_membership).provide(:default, parent: Puppet::Provider::Ipa) do
  defaultfor kernel: 'Linux'

  # always need to define this in our implementation classes
  mk_resource_methods

  ##########################
  # private methods that we need to implement because we inherit from Puppet::Provider::Synapse

  # In this case we need to be pretty different about how we handle group memberships
  # because they are special, so we aren't using a cache here
  def read_instance(*)
    # TODO: read from a "groups cache"
    body = {
      'id' => 0,
      'method' => 'group_find/1',
      'params' => [
        # args (positional arguments)
        [resource[:group]],
        # options (CLI flags / options)
        {
          'all' => true,
        },
      ],
    }
    response_body = api_post('/session/json', body: body, json_parse: true)
    group_list = response_body['result']['result']
    group = group_list.find { |g| get_ldap_attribute(g, 'cn') == resource[:group] }
    Puppet.debug("Got group: #{group}")

    instance = nil
    unless group.nil?
      instance = {
        ensure: :present,
        name: resource[:name],
        group: get_ldap_attribute(group, 'cn'),
      }
      instance[:groups] = get_ldap_attribute(group, 'member_group') if resource[:groups]
      instance[:users] = get_ldap_attribute(group, 'member_user') if resource[:users]
      instance[:services] = get_ldap_attribute(group, 'member_service') if resource[:services]

      # if we are trying to delete the instance and all of the memberships are gone, then tell
      # Puppet that its gone
      if resource[:ensure] == :absent &&
         (instance[:groups].nil? || instance[:groups] == :absent) &&
         (instance[:users].nil? || instance[:users] == :absent) &&
         (instance[:services].nil? || instance[:services] == :absent)
        instance = nil
      end
    end
    instance = { ensure: :absent, name: resource[:name] } if instance.nil?
    Puppet.debug("Returning group membership instance #{instance}")
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
    # write a single instance at a time
    # we can't bulk write because instances may be written in different orders depending
    # on their relationships defined in PuppetDSL
    method = if resource[:ensure] == :absent
               'group_remove_member/1'
             else
               'group_add_member/1'
             end

    body = {
      'id' => 0,
      'method' => method,
      'params' => [
        # args (positional arguments)
        [resource[:group]],
        # options (CLI flags / options)
        {},
      ],
    }
    body['params'][1]['group'] = resource[:groups] if resource[:groups]
    body['params'][1]['user'] = resource[:users] if resource[:users]
    body['params'][1]['service'] = resource[:services] if resource[:services]

    api_post('/session/json', body: body)
  end
end
