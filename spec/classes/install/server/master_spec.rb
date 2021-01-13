require 'spec_helper'

describe 'ipa::install::server::master' do
  mock_firewalld

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge(fqdn: 'master01.ipa.domain.tld') }

      let(:pre_condition) do
        <<-EOS
        class { 'ipa':
          admin_user           => 'admin',
          admin_password       => 'AdminPassword123',
          domain               => 'ipa.domain.tld',
          domain_join_password => 'IpaJoin123',
          ds_password          => 'DsPassword123',
          ipa_role             => 'master',
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
ipa_hostname = master01.ipa.domain.tld
chpass_provider = ipa
# on masters/replicas, set ipa_server to itself to avoid this bug: https://access.redhat.com/solutions/3178971
ipa_server = master01.ipa.domain.tld
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
          .that_requires('Exec[server_install_master01.ipa.domain.tld]')
          .that_notifies('Ipa::Helpers::Flushcache[server_master01.ipa.domain.tld]')
      end
    end
  end
end
