Puppet::Type.newtype(:ipa_user) do
  desc 'Manages a user in IPA'

  ensurable do
    newvalue(:present) do
      provider.create
    end

    newvalue(:absent) do
      provider.destroy
    end

    defaultto :present
  end

  # namevar is always a parameter
  newparam(:name, namevar: true) do
    desc 'Username of the user'

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "name is expected to be an String, given: #{value.class.name}"
      end
    end
  end

  newparam(:initial_password) do
    desc 'Initial password for the user. This is only used when creating the user and not managed going forward'

    isrequired

    sensitive true

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "initial_password is expected to be an String, given: #{value.class.name}"
      end
    end
  end

  newproperty(:first_name) do
    desc 'First name for the user. This will be the "givenname" LDAP parameter.'

    defaultto do
      @resource[:name]
    end

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "first_name is expected to be an String, given: #{value.class.name}"
      end
    end
  end

  newproperty(:last_name) do
    desc 'Last name for the user. This will be the "sn" LDAP parameter.'

    defaultto do
      @resource[:name]
    end

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "last_name is expected to be an String, given: #{value.class.name}"
      end
    end
  end

  newproperty(:sshpubkeys, array_matching: :all) do
    validate do |value|
      # note: Puppet automatically detects if the value is an array and calls this validate()
      #       on each item/value within the array
      unless value.is_a?(String)
        raise ArgumentError, "sshpubkeys are expected to be String, given: #{value.class.name}"
      end
    end

    # sort the array so we can compute the difference correct and order doesn't matter
    def sort_array(a)
      if a.nil?
        []
      else
        a.sort
      end
    end

    def should
      sort_array(super)
    end

    def should=(values)
      super(sort_array(values))
    end

    def insync?(is)
      sort_array(is) == should
    end
  end

  newproperty(:mail) do
    desc 'Email address of the user'

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "mail is expected to be an String, given: #{value.class.name}"
      end
    end
  end

  newproperty(:ldap_attributes) do
    desc 'Hash of additional IPA attributes to set on the user'

    validate do |value|
      unless value.is_a?(Hash)
        raise ArgumentError, "ldap_attributes is expected to be a Hash, given: #{value.class.name}"
      end
    end

    munge do |value|
      # the IPA API downcases all keys, so we do the same to make sure the attributes match
      value.transform_keys(&:downcase)
    end
  end

  newparam(:api_url) do
    desc 'URL of the IPA API. Note: we will append endpoints to the end of this. Default: https://<Facter.value(:fqdn)>/ipa'

    isrequired

    defaultto do
      "https://#{Facter.value(:fqdn)}/ipa"
    end

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "api_url is expected to be an String, given: #{value.class.name}"
      end
    end
  end

  newparam(:api_username) do
    desc 'Username for authentication to the API. This user must be an admin user.'

    isrequired

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "api_username is expected to be an String, given: #{value.class.name}"
      end
    end
  end

  newparam(:api_password) do
    desc 'Password for authentication to the API.'

    isrequired

    sensitive true

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "api_password is expected to be an String, given: #{value.class.name}"
      end
    end
  end
end
