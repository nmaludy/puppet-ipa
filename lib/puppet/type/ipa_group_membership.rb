require 'puppet_x/encore/ipa/list_property'
require 'puppet_x/encore/ipa/type_utils'

Puppet::Type.newtype(:ipa_group_membership) do
  desc 'Manages a membership of a group. Group membership can be user->group, group->group, external->group (TODO), idoverride->group (TODO), service->group.'

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
    desc <<-EOS
      Unique name of the membership, by default we use this for the group name
      We support this NOT being the group name in case you want to manage membership
      in a unique way.
    EOS

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:group) do
    desc 'Name of the group who members will be managed'

    defaultto do
      @resource[:name]
    end

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newparam(:membership) do
    desc <<-EOS
      Whether specified members should be considered the **complete list**
      (`inclusive`) or the **minimum list** (`minimum`) of members the group has.
    EOS

    newvalues(:inclusive, :minimum)

    defaultto :minimum
  end

  newproperty(:groups, array_patching: :all, parent: PuppetX::Encore::Ipa::ListProperty) do
    desc 'Group members of this group'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:users, array_patching: :all, parent: PuppetX::Encore::Ipa::ListProperty) do
    desc 'User members of this group'

    validate do |value|
      PuppetX::Encore::Ipa::TypeUtils.validate_string(name, value)
    end
  end

  newproperty(:services, array_patching: :all, parent: PuppetX::Encore::Ipa::ListProperty) do
    desc 'Service members of this group'

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

  autorequire(:ipa_group) do
    grp = [@parameters[:group].should]
    grp += @parameters[:groups].should if @parameters[:groups] && @parameters[:groups].should
    grp
  end

  autorequire(:ipa_user) do
    (@parameters[:users]) ? @parameters[:users].should : []
  end
end
