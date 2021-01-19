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
        raise ArgumentError, "password is expected to be an String, given: #{value.class.name}"
      end
    end
  end

  newproperty(:first_name) do
    desc 'First name for the user'

    defaultto do
      @resource[:name]
    end

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "first is expected to be an String, given: #{value.class.name}"
      end
    end
  end

  newproperty(:last_name) do
    desc 'Last name for the user'

    defaultto do
      @resource[:name]
    end

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "first is expected to be an String, given: #{value.class.name}"
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
