Puppet::Type.newtype(:ipa_kinit) do
  desc 'Ensures a kereberos ticket is obtained for a given user'

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
    desc 'Username to obtain a kerberose ticket for'

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "name is expected to be an String, given: #{value.class.name}"
      end
    end
  end

  newparam(:realm) do
    desc 'Optional realm to help with user matching when running klist.'

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "api_password is expected to be an String, given: #{value.class.name}"
      end
    end

    munge do |value|
      value.upcase
    end
  end

  newparam(:password) do
    desc 'Password for the user'

    isrequired

    sensitive true

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "api_password is expected to be an String, given: #{value.class.name}"
      end
    end
  end
end
