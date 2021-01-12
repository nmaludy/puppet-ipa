#
class ipa::install::server::master (
  String   $admin_pass           = $ipa::admin_password,
  String   $admin_user           = $ipa::admin_user,
  String   $cmd_opts_dns         = $ipa::install::server::server_install_cmd_opts_setup_dns,
  String   $cmd_opts_dnssec      = $ipa::install::server::server_install_cmd_opts_dnssec_validation,
  String   $cmd_opts_forwarders  = $ipa::install::server::server_install_cmd_opts_forwarders,
  String   $cmd_opts_hostname    = $ipa::install::server::server_install_cmd_opts_hostname,
  String   $cmd_opts_idstart     = $ipa::install::server::server_install_cmd_opts_idstart,
  String   $cmd_opts_ntp         = $ipa::install::server::server_install_cmd_opts_no_ntp,
  String   $cmd_opts_ui          = $ipa::install::server::server_install_cmd_opts_no_ui_redirect,
  String   $cmd_opts_zones       = $ipa::install::server::server_install_cmd_opts_zone_overlap,
  String   $ds_password          = $ipa::ds_password,
  String   $ipa_domain           = $ipa::domain,
  String   $ipa_realm            = $ipa::final_realm,
  String   $ipa_role             = $ipa::ipa_role,
) {

  # Build server-install command
  $server_install_cmd = @("EOC"/)
    ipa-server-install ${cmd_opts_hostname} \
    --realm=${ipa_realm} \
    --domain=${ipa_domain} \
    --admin-password=\$IPA_ADMIN_PASS \
    --ds-password=\$DS_PASSWORD \
    ${cmd_opts_dnssec} \
    ${cmd_opts_forwarders} \
    ${cmd_opts_idstart} \
    ${cmd_opts_ntp} \
    ${cmd_opts_ui} \
    ${cmd_opts_dns} \
    ${cmd_opts_zones} \
    --unattended
    | EOC

  # Build kinit command (Puppet doesn't like to escape $ nor accept all cap variables)
  $kinit_cmd = @("EOC"/)
    echo \$IPA_ADMIN_PASS | kinit ${admin_user}
    | EOC

  # Set default login shell command
  $config_shell_cmd = 'ipa config-mod --defaultshell="/bin/bash"'

  # Set default password policy command
  $config_pw_policy_cmd = 'ipa pwpolicy-mod --maxlife=365'


  facter::fact { 'ipa_role':
    value => $ipa_role,
  }

  file { '/etc/ipa/primary':
    ensure  => 'file',
    content => 'Added by IPA Puppet module. Designates primary master. Do not remove.',
  }

  -> exec { "server_install_${::hostname}":
    command     => $server_install_cmd,
    environment => [ "IPA_ADMIN_PASS=${admin_pass}", "DS_PASSWORD=${ds_password}" ],
    path        => ['bin', '/sbin', '/usr/sbin'],
    timeout     => 0,
    unless      => '/usr/sbin/ipactl status >/dev/null 2>&1',
    creates     => '/etc/ipa/default.conf',
    logoutput   => 'on_failure',
    notify      => Exec['kinit_master_install'],
  }

  facter::fact { 'ipa_installed':
    value => true,
  }

  # Updated master sssd.conf file after IPA is installed.
  file { '/etc/sssd/sssd.conf':
    content => template('ipa/sssd.conf.erb'),
    mode    => '0600',
    require => Exec["server_install_${::hostname}"],
    notify  => Ipa::Helpers::Flushcache["server_${::fqdn}"],
  }

  exec { 'kinit_master_install':
    command     => $kinit_cmd,
    environment => [ "IPA_ADMIN_PASS=${admin_pass}" ],
    path        => ['/bin'],
    refreshonly => true,
  }

  # Configure IPA server default settings.
  -> exec { 'ipa_config_mod_shell':
    command     => $config_shell_cmd,
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
  }

  -> exec { 'ipa_pwpolicy_mod_pass_age':
    command     => $config_pw_policy_cmd,
    path        => ['/bin', '/usr/bin'],
    refreshonly => true,
  }

}
