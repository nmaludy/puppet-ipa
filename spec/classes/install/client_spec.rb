require 'spec_helper'

describe 'ipa::install::client' do
  mock_firewalld

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context 'when ipa_role=client' do
        let(:facts) { os_facts.merge(fqdn: 'client01.ipa.domain.tld') }

        let(:pre_condition) do
          <<-'EOS'
class { 'ipa':
  domain               => 'ipa.domain.tld',
  domain_join_password => 'IpaJoin123',
  ipa_role             => 'client',
  ipa_master_fqdn      => 'ipa01.ipa.domain.tld',
}
EOS
        end

        let(:sssd_conf) do
          <<-'EOS'
[domain/ipa.domain.tld]
debug_level = 3
cache_credentials = True
krb5_store_password_if_offline = True
ipa_domain = ipa.domain.tld
id_provider = ipa
auth_provider = ipa
access_provider = ipa
ipa_hostname = client01.ipa.domain.tld
chpass_provider = ipa
ipa_server = _srv_, ipa01.ipa.domain.tld
ldap_tls_cacert = /etc/ipa/ca.crt
autofs_provider = ipa
ipa_automount_location = default
subdomain_inherit = ldap_user_principal
ldap_user_principal = nosuchattr

[sssd]
debug_level = 3
services = nss,sudo,pam,ssh,autofs
domains = ipa.domain.tld

[nss]
debug_level = 3
homedir_substring = /home
default_shell = /bin/bash

[pam]
debug_level = 3

[sudo]
debug_level = 3

[autofs]
debug_level = 3

[ssh]
debug_level = 3

[pac]
debug_level = 3

[ifp]
debug_level = 3
EOS
        end

        it do
          is_expected.to compile
        end
        it do
          is_expected.to contain_file('/etc/sssd/sssd.conf')
            .with('ensure'  => 'file',
                  'mode'    => '0600',
                  'content' => sssd_conf)
            .that_requires(['Package[sssd-common]', 'Exec[client_install_client01.ipa.domain.tld]'])
            .that_notifies('Ipa::Helpers::Flushcache[server_client01.ipa.domain.tld]')
        end
      end

      context 'when ipa_role=replica' do
        let(:facts) { os_facts.merge(fqdn: 'replica01.ipa.domain.tld') }

        let(:pre_condition) do
          <<-'EOS'
class { 'ipa':
  domain               => 'ipa.domain.tld',
  domain_join_password => 'IpaJoin123',
  ipa_role             => 'replica',
  ipa_master_fqdn      => 'ipa01.ipa.domain.tld',
}
EOS
        end

        let(:sssd_conf) do
          <<-'EOS'
[domain/ipa.domain.tld]
debug_level = 3
cache_credentials = True
krb5_store_password_if_offline = True
ipa_domain = ipa.domain.tld
id_provider = ipa
auth_provider = ipa
access_provider = ipa
ipa_hostname = replica01.ipa.domain.tld
chpass_provider = ipa
# on masters/replicas, set ipa_server to itself to avoid this bug: https://access.redhat.com/solutions/3178971
ipa_server = replica01.ipa.domain.tld
ipa_server_mode = True
ldap_tls_cacert = /etc/ipa/ca.crt
autofs_provider = ipa
ipa_automount_location = default
subdomain_inherit = ldap_user_principal
ldap_user_principal = nosuchattr

[sssd]
debug_level = 3
services = nss,sudo,pam,ssh,autofs
domains = ipa.domain.tld

[nss]
debug_level = 3
homedir_substring = /home
default_shell = /bin/bash
memcache_timeout = 300

[pam]
debug_level = 3

[sudo]
debug_level = 3

[autofs]
debug_level = 3

[ssh]
debug_level = 3

[pac]
debug_level = 3

[ifp]
debug_level = 3

[secrets]
debug_level = 3

[session_recording]
EOS
        end

        it do
          is_expected.to compile
        end
        it do
          is_expected.to contain_file('/etc/sssd/sssd.conf')
            .with('ensure'  => 'file',
                  'mode'    => '0600',
                  'content' => sssd_conf)
            .that_requires(['Package[sssd-common]', 'Exec[client_install_replica01.ipa.domain.tld]'])
            .that_notifies('Ipa::Helpers::Flushcache[server_replica01.ipa.domain.tld]')
        end
      end
    end
  end
end
