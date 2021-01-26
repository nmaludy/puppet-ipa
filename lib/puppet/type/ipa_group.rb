require 'puppet_x/encore/ipa/type_utils'

Puppet::Type.newtype(:ipa_group) do
  desc 'Manages a user group in IPA'

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
    desc 'Name of the group'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:description) do
    desc 'Description of the group'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:group_type) do
    desc <<-EOS
      Type of the IPA group to create. When creating POSIX groups, you can specify the gid.
      Once a groups is created, it is not possible to change its group type. Attempting
      to do so will result in an error from the API.
    EOS

    newvalue(:posix)
    newvalue(:non_posix)
    newvalue(:external)

    defaultto :posix
  end

  newproperty(:gid) do
    desc 'Group ID of the group, (only for POSIX groups)'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_type(name, value, Integer)
      unless @resource[:group_type] == :posix
        raise ArgumentError, 'gid is only allowed to be specified when creating POSIX groups.'
      end
    end
  end

  newparam(:api_url) do
    desc 'URL of the IPA API. Note: we will append endpoints to the end of this. Default: https://<Facter.value(:fqdn)>/ipa'

    isrequired

    defaultto do
      "https://#{Facter.value(:fqdn)}/ipa"
    end

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newparam(:api_username) do
    desc 'Username for authentication to the API. This user must be an admin user.'

    isrequired

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newparam(:api_password) do
    desc 'Password for authentication to the API.'

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
