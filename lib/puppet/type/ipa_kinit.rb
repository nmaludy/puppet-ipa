require 'puppet_x/encore/ipa/type_utils'

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
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newparam(:realm) do
    desc 'Optional realm to help with user matching when running klist.'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
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
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  validate do
    PuppetX::Encore::Ipa::TypeUtils.validate_required_attributes(self)
  end
end
