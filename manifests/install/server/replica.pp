#
class ipa::install::server::replica (
  String             $admin_pass       = $ipa::admin_password,
  String             $admin_user       = $ipa::admin_user,
  String             $cmd_opts_setup_ca = $ipa::install::server::server_install_cmd_opts_setup_ca,
  String   $cmd_opts_dns         = $ipa::install::server::server_install_cmd_opts_setup_dns,
  String   $cmd_opts_dnssec      = $ipa::install::server::server_install_cmd_opts_dnssec_validation,
  String   $cmd_opts_forwarders  = $ipa::install::server::server_install_cmd_opts_forwarders,
  String   $cmd_opts_hostname    = $ipa::install::server::server_install_cmd_opts_hostname,
  String   $cmd_opts_ntp         = $ipa::install::server::server_install_cmd_opts_no_ntp,
  String   $cmd_opts_ui          = $ipa::install::server::server_install_cmd_opts_no_ui_redirect,
  String   $cmd_opts_zones       = $ipa::install::server::server_install_cmd_opts_zone_overlap,
  String             $ipa_role         = $ipa::ipa_role,
  Sensitive[String]  $principal_pass   = $ipa::final_domain_join_password,
  String             $principal_user   = $ipa::final_domain_join_principal,
  String             $service_restart  = $ipa::params::service_restart_epp,
  String             $sssd_service     = $ipa::params::sssd_service,
) {
  # Build replica install command
  $replica_install_cmd = @("EOC"/)
    ipa-replica-install \
    --principal=${principal_user} \
    --admin-password=\$IPA_ADMIN_PASS \
    ${cmd_opts_setup_ca} \
    ${cmd_opts_dnssec} \
    ${cmd_opts_forwarders} \
    ${cmd_opts_ntp} \
    ${cmd_opts_ui} \
    ${cmd_opts_dns} \
    ${cmd_opts_zones} \
    --unattended
    | EOC

  # Set puppet fact for IPA role
  facter::fact { 'ipa_role':
    value => $ipa_role,
  }

  contain ipa::helpers::firewalld

  include ipa::install::server::kinit

  # Needed to ensure ipa-replica-install succeeds if new client is installed.
  exec { 'replica_restart_sssd':
    command     => inline_epp($service_restart, {'service' => $sssd_service}),
    environment => [ "IPA_ADMIN_PASS=${principal_pass.unwrap}" ],
    # try to kinit and restart sssd if kinit fails
    unless      => "echo \$IPA_ADMIN_PASS | kinit ${principal_user}",
    path        => ['/sbin', '/bin', '/usr/bin', '/usr/sbin'],
    tag         => 'ipa::install::replica',
  }
  -> Ipa_kinit[$admin_user]
  -> exec { 'replica_server_install':
    command     => $replica_install_cmd,
    environment => [ "IPA_ADMIN_PASS=${principal_pass.unwrap}" ],
    path        => ['/bin', '/sbin', '/usr/bin', '/usr/sbin'],
    timeout     => 0,
    # only attempt to reinstall if IPA is not configured
    onlyif      => 'ipactl status 2>&1 | grep -i "IPA is not configured"',
    logoutput   => 'on_failure',
    require     => Class['ipa::helpers::firewalld'],
    notify      => Ipa::Helpers::Flushcache["server_${$facts['fqdn']}"],
  }

  facter::fact { 'ipa_installed':
    value => 'true',
  }

}
