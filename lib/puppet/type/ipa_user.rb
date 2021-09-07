require 'puppet/property/boolean'
require 'puppet_x/encore/ipa/boolean_property'
require 'puppet_x/encore/ipa/list_property'
require 'puppet_x/encore/ipa/type_utils'

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
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newparam(:initial_password) do
    desc 'Initial password for the user. This is only used when creating the user and not managed going forward'

    isrequired

    sensitive true

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:enable, boolean: true, parent: PuppetX::Encore::Ipa::BooleanProperty) do
    desc 'Account is enabled or not'

    defaultto :true  # yes, use a symbol here
  end

  newproperty(:first_name) do
    desc 'First name for the user. This will be the "givenname" LDAP parameter.'

    defaultto do
      @resource[:name]
    end

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:last_name) do
    desc 'Last name for the user. This will be the "sn" LDAP parameter.'

    defaultto do
      @resource[:name]
    end

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:sshpubkeys, array_matching: :all, parent: PuppetX::Encore::Ipa::ListProperty) do
    validate do |value|
      # note: Puppet automatically detects if the value is an array and calls this validate()
      #       on each item/value within the array
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end

    def membership
      :sshpubkey_membership
    end
  end

  newparam(:sshpubkey_membership) do
    desc "Whether specified SSH public keys should be considered the **complete list**
        (`inclusive`) or the **minimum list** (`minimum`) of roles the user
        has."

    newvalues(:inclusive, :minimum)

    defaultto :minimum
  end

  newproperty(:login_shell) do
    desc 'Login shell for the user'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:mail) do
    desc 'Email address of the user'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:job_title) do
    desc 'Job title of the user'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:ldap_attributes) do
    desc 'Hash of additional IPA attributes to set on the user'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_type(name, value, Hash)
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
