require 'spec_helper'

describe Puppet::Type.type(:ipa_kinit) do
  let(:name) { 'admin' }

  let(:required_properties) do
    {
      ensure: :present,
      name: name,
      password: 'Password123',
    }
  end

  let(:optional_properties) do
    {
      realm: 'IPA.DOMAIN.TLD',
    }
  end

  let(:properties) do
    required_properties.merge(optional_properties)
  end

  let(:type_instance) do
    Puppet::Type.type(:ipa_kinit).new(properties)
  end

  describe '#name' do
    it 'have a name parameter' do
      expect(Puppet::Type.type(:ipa_kinit).attrtype(:name)).to eq(:param)
    end
    it 'raise ArgumentError if not valid value' do
      expect { Puppet::Type.type(:ipa_kinit).new(required_properties.merge(name: 123)) }.to raise_error(Puppet::ResourceError)
    end
    it 'validate and pass if valid value' do
      expect(type_instance[:name]).to eq(name)
    end
  end

  describe '#realm' do
    it 'have a realm parameter' do
      expect(Puppet::Type.type(:ipa_kinit).attrtype(:realm)).to eq(:param)
    end
    it 'raise ArgumentError if not valid value' do
      expect {
        Puppet::Type.type(:ipa_kinit).new(required_properties.merge(realm: 123))
      }.to raise_error(Puppet::ResourceError)
    end
    it 'validate and pass if valid value' do
      expect(type_instance[:realm]).to eq('IPA.DOMAIN.TLD')
    end
    it 'munge lowercase realms into uppercase' do
      props = required_properties.merge(realm: 'lower.domain.tld')
      instance = Puppet::Type.type(:ipa_kinit).new(props)
      expect(instance[:realm]).to eq('LOWER.DOMAIN.TLD')
    end
  end

  describe '#password' do
    it 'have a password parameter' do
      expect(Puppet::Type.type(:ipa_kinit).attrtype(:password)).to eq(:param)
    end
    it 'raise ArgumentError if not valid value' do
      expect {
        Puppet::Type.type(:ipa_kinit).new(required_properties.merge(password: 123))
      }.to raise_error(Puppet::ResourceError)
    end
    it 'validate and pass if valid value' do
      expect(type_instance[:password]).to eq('Password123')
    end
  end

  describe '#ensure' do
    it 'have a ensure property' do
      expect(Puppet::Type.type(:ipa_kinit).attrtype(:ensure)).to eq(:property)
    end
    it 'raise ArgumentError if not valid value' do
      expect {
        Puppet::Type.type(:ipa_kinit).new(required_properties.merge(ensure: 'some_bad_value'))
      }.to raise_error(Puppet::ResourceError)
    end
    it 'validate and pass if valid value' do
      expect(type_instance[:ensure]).to eq(:present)
    end
    it 'default to :present' do
      type = Puppet::Type.type(:ipa_kinit).new(name: name, password: 'Password123')
      expect(type[:ensure]).to eq(:present)
    end
  end
end
