# Install and configure trust_ad if enabled
class ipa::install::server::trust_ad (
  String  $ad_admin     = $ipa::ad_trust_admin,
  String  $ad_domain    = $ipa::ad_trust_realm,
  Array   $ad_groups    = $ipa::ad_groups,
  String  $admin_pass   = $ipa::admin_password,
  String  $admin_user   = $ipa::admin_user,
  String  $ad_password  = $ipa::ad_trust_password,
  String  $ad_realm     = $ipa::ad_trust_realm,
  String  $ipa_role     = $ipa::ipa_role,
) {

  package { 'ipa-server-trust-ad':
    ensure => 'present',
  }

  if $ipa_role == 'master' {
    $ad_trust_install_opts = "-a ${admin_pass}"
  } else {
    $ad_trust_install_opts = '--add-agents'
  }

  # Build adtrust install command
  $adtrust_install_cmd = @("EOC")
    ipa-adtrust-install \
    ${ad_trust_install_opts} \
    --unattended
    | EOC

  # Build trust-add command
  $trust_add_cmd = @("EOC"/)
    echo \$AD_PASSWORD | ipa trust-add ${ad_realm} \
    --admin=${ad_admin} \
    --password
    | EOC

  # Build kinit command (Puppet doesn't like to escape $ nor accept all cap variables)
  $kinit_cmd = @("EOC"/)
    echo \$IPA_ADMIN_PASS | kinit ${admin_user}
    | EOC


  if $ad_password != '' and str2bool($facts['trust_ad']) != true {
    exec { 'trust_ad_kinit_admin':
      command     => $kinit_cmd,
      environment => [ "IPA_ADMIN_PASS=${admin_pass}" ],
      path        => ['bin', '/sbin', '/usr/sbin'],
    }
    -> exec { 'trust_ad_install':
      command   => $adtrust_install_cmd,
      path      => ['bin', '/sbin', '/usr/sbin'],
      logoutput => 'on_failure',
      notify    => Ipa::Helpers::Flushcache["server_${::fqdn}"],
    }
    ~> exec { 'trust_ad_trust_add':
      command     => $trust_add_cmd,
      environment => [ "AD_PASSWORD=${ad_password}" ],
      path        => ['/bin', '/usr/bin'],
      logoutput   => 'on_failure',
      refreshonly => true,
    }
    ~> exec { 'trust_ad_kdestroy':
      command => 'kdestroy',
      path    => ['bin', '/usr/bin'],
    }

    ~> facter::fact { 'trust_ad':
      value     => true,
    }
  }

  # NOTE: If no credentials supplied:
  #  You MUST manually run "ipa trust-add ${ad_realm}" with a valid domain
  #  administrator and password to facilitate LDAP integration.
  #
  #  $ ipa trust-add <AD_DOMAIN> --admin=<AD_ADMIN> --password
  #  password: <AD_ADMIN_PASSWORD>  # Will prompt for password

  # Copy IPA helper scripts to host
  file { '/root/01_config_ipa_ldap.sh':
    ensure  => file,
    mode    => '0750',
    owner   => 'root',
    group   => 'root',
    content => template('ipa/config_ipa_ldap.sh.erb'),
  }

  file { '/root/02_id_override.sh':
    ensure  => file,
    mode    => '0750',
    owner   => 'root',
    group   => 'root',
    content => template('ipa/id_override.sh.erb'),
  }
}
