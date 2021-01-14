require 'spec_helper'

describe 'ipa::install::server::master' do
  mock_firewalld

  let(:fqdn) { 'master01.ipa.domain.tld' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      context 'with default params' do
        let(:facts) { os_facts.merge(fqdn: fqdn) }

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
            .that_requires("Exec[server_install_#{fqdn}]")
            .that_notifies("Ipa::Helpers::Flushcache[server_#{fqdn}]")
        end
        it do
          is_expected.to contain_exec("server_install_#{fqdn}")
            .with('command' => "ipa-server-install --hostname=#{fqdn} --realm=IPA.DOMAIN.TLD --domain=ipa.domain.tld --admin-password=$IPA_ADMIN_PASS --ds-password=$DS_PASSWORD   --idstart=69678 --no-ntp    --unattended\n", # rubocop:disable LineLength
                  'environment' => ['IPA_ADMIN_PASS=AdminPassword123',
                                    'DS_PASSWORD=DsPassword123'],
                  'path'        => ['/bin', '/sbin', '/usr/sbin', '/usr/bin'],
                  'timeout'     => 0,
                  'unless'      => '/usr/sbin/ipactl status >/dev/null 2>&1',
                  'creates'     => '/etc/ipa/default.conf',
                  'logoutput'   => 'on_failure')
            .that_requires('File[/etc/ipa/primary]')
            .that_notifies('Ipa_kinit[admin]')
        end
      end

      context 'with no_ui_redirect' do
        let(:facts) { os_facts.merge(fqdn: fqdn) }

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
            no_ui_redirect       => true,
          }
          EOS
        end

        it { is_expected.to compile }
        it do
          is_expected.to contain_exec("server_install_#{fqdn}")
            .with('command' => "ipa-server-install --hostname=#{fqdn} --realm=IPA.DOMAIN.TLD --domain=ipa.domain.tld --admin-password=$IPA_ADMIN_PASS --ds-password=$DS_PASSWORD   --idstart=69678 --no-ntp --no-ui-redirect   --unattended\n", # rubocop:disable LineLength
                  'environment' => ['IPA_ADMIN_PASS=AdminPassword123',
                                    'DS_PASSWORD=DsPassword123'],
                  'path'        => ['/bin', '/sbin', '/usr/sbin', '/usr/bin'],
                  'timeout'     => 0,
                  'unless'      => '/usr/sbin/ipactl status >/dev/null 2>&1',
                  'creates'     => '/etc/ipa/default.conf',
                  'logoutput'   => 'on_failure')
            .that_requires('File[/etc/ipa/primary]')
            .that_notifies('Ipa_kinit[admin]')
        end
      end
    end
  end
end
