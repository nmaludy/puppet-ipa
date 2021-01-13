require 'spec_helper'

describe 'ipa::install::sssd' do
  mock_firewalld

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge(fqdn: 'hostname.domain.tld') }

      let(:flush_sssd) do
        <<-'EOS'
#!/bin/bash

check_command_exists() {
  (which "$1") > /dev/null 2>&1
  command_exists=$?
  return $command_exists
}

check_command_exists "systemctl"
is_systemd=$?
check_command_exists "service"
is_service=$?

service_mgt() {
  action="$1"
  name="$2"
  if [ $is_systemd -eq 0 ]; then
    systemctl "$action" "$name"
  else
    service "$name" "$action"
  fi
  return $?
}

service_mgt "stop" "sssd"
rm -rf /var/lib/sss/db/* /var/lib/sss/mc/*
service_mgt "start" "sssd"

service_mgt "restart" "autofs"

service_mgt "status" "sssd"
service_mgt "status" "autofs"
EOS
      end

      it do
        is_expected.to compile
      end
      it do
        is_expected.to contain_package('sssd-common')
          .with('ensure' => 'present')
      end
      it do
        is_expected.to contain_file('flush_sssd_cache_hostname.domain.tld')
          .with('ensure'  => 'file',
                'path'    => '/root/flush_sssd_cache.sh',
                'content' => flush_sssd,
                'mode'    => '0750',
                'owner'   => 'root',
                'group'   => 'root')
      end
    end
  end
end
