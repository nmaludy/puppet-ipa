require 'spec_helper'

describe 'ipa::install::client' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      let(:pre_condition) do
        <<-'EOS'
class { 'ipa':
  domain               => 'domain.tld',
  domain_join_password => 'IpaJoin123',
  ipa_role             => 'client',
  ipa_master_fqdn      => 'ipa.domain.tld',
}
EOS
      end

      it do
        is_expected.to contain_file('/etc/sssd/sssd.conf')
          .with('ensure'  => 'file',
                'mode'    => '0600')
      end
    end
  end
end
