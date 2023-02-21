#
class ipa::install::server::master (
  String             $ad_domain            = $ipa::ad_domain,
  String             $ad_ldap_search_base  = $ipa::ad_ldap_search_base,
  String             $ad_site              = $ipa::ad_site,
  String   $admin_pass           = $ipa::admin_password,
  String   $admin_user           = $ipa::admin_user,
  String             $automount_location   = $ipa::automount_location,

  String   $cmd_opts_dns         = $ipa::install::server::server_install_cmd_opts_setup_dns,
  String   $cmd_opts_dnssec      = $ipa::install::server::server_install_cmd_opts_dnssec_validation,
  String   $cmd_opts_forwarders  = $ipa::install::server::server_install_cmd_opts_forwarders,
  String   $cmd_opts_hostname    = $ipa::install::server::server_install_cmd_opts_hostname,
  String   $cmd_opts_idstart     = $ipa::install::server::server_install_cmd_opts_idstart,
  String   $cmd_opts_ntp         = $ipa::install::server::server_install_cmd_opts_no_ntp,
  String   $cmd_opts_ui          = $ipa::install::server::server_install_cmd_opts_no_ui_redirect,
  String   $cmd_opts_zones       = $ipa::install::server::server_install_cmd_opts_zone_overlap,
  String   $ds_password          = $ipa::ds_password,
  Boolean           $ignore_group_members = $ipa::ignore_group_members,
  Boolean           $install_autofs       = $ipa::install_autofs,
  String   $ipa_domain           = $ipa::domain,
  String   $ipa_realm            = $ipa::final_realm,
  String   $ipa_role             = $ipa::ipa_role,
  String            $ipa_master_fqdn      = $ipa::ipa_master_fqdn,
  Optional[String]  $override_homedir     = $ipa::override_homedir,
  String            $sssd_debug_level     = $ipa::sssd_debug_level,
  Array[String]     $sssd_services        = $ipa::sssd_services,
  Hash[String, Hash[String, Any]] $sssd_config_entries = $ipa::sssd_config_entries,
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

  -> exec { "server_install_${$facts['fqdn']}":
    command     => $server_install_cmd,
    environment => [ "IPA_ADMIN_PASS=${admin_pass}", "DS_PASSWORD=${ds_password}" ],
    path        => ['/bin', '/sbin', '/usr/sbin', '/usr/bin'],
    timeout     => 0,
    unless      => '/usr/sbin/ipactl status >/dev/null 2>&1',
    creates     => '/etc/ipa/default.conf',
    logoutput   => 'on_failure',
    notify      => Ipa_kinit[$admin_user],
  }

  facter::fact { 'ipa_installed':
    value => 'true',
  }

  # Updated master sssd.conf file after IPA is installed.
  file { '/etc/sssd/sssd.conf':
    ensure  => file,
    content => epp('ipa/sssd.conf.epp', {
      ad_domain            => $ad_domain,
      ad_ldap_search_base  => $ad_ldap_search_base,
      ad_site              => $ad_site,
      automount_location   => $automount_location,
      domain               => $ipa_domain,
      fqdn                 => $facts['fqdn'],
      ignore_group_members => $ignore_group_members,
      install_autofs       => $install_autofs,
      ipa_master_fqdn      => $ipa_master_fqdn,
      ipa_role             => $ipa_role,
      override_homedir     => $override_homedir,
      sssd_debug_level     => $sssd_debug_level,
      sssd_services        => $sssd_services,
      config_entries       => $sssd_config_entries,
    }),
    mode    => '0600',
    require => Exec["server_install_${$facts['fqdn']}"],
    notify  => Ipa::Helpers::Flushcache["server_${$facts['fqdn']}"],
  }

  include ipa::install::server::kinit

  # Configure IPA server default settings.
  Ipa_kinit[$admin_user]
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
