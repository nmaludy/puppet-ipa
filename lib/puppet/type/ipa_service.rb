require 'puppet_x/encore/ipa/type_utils'

Puppet::Type.newtype(:ipa_service) do
  desc 'Manages a Kerberos Service principal in IPA'

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
    desc 'Name of the service'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
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
