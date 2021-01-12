#
class ipa::install::server::autofs (
  String  $ad_domain             = $ipa::ad_trust_realm,
  String  $admin_pass            = $ipa::admin_password,
  String  $admin_user            = $ipa::admin_user,
  String  $autofs_package        = $ipa::params::autofs_package_name,
  String  $automount_home_dir    = "/home/ipa/${ad_domain}",
  String  $automount_home_share  = undef,
  String  $automount_location    = undef,
) {

  # Build kinit command (Puppet doesn't like to escape $ nor accept all cap variables)
  $kinit_cmd = @("EOC"/)
    echo \$IPA_ADMIN_PASS | kinit ${admin_user}
    | EOC

  # automount map home command
  $map_home_cmd = "ipa automountmap-add ${automount_location} auto.home"

  # Build automount auto.home key
  $key_home_cmd = @("EOC"/)
    ipa automountkey-add ${automount_location} auto.home \
    --key='*' \
    --info="-fstype=nfs4 ${automount_home_share}"
    | EOC

  # Build automount auto.master key
  $key_master_cmd = @("EOC"/)
    ipa automountkey-add ${automount_location} auto.master \
    --key="${automount_home_dir}" \
    --info=auto.home
    | EOC

  # Set default homedirectory command
  $config_homedir_cmd = "ipa config-mod --homedirectory='${automount_home_dir}'"

  # install the package
  ensure_resource('package', $autofs_package, { 'ensure' => 'present' })

  if str2bool($facts['autofs_installed']) != true {

    exec { 'kinit_autofs_configure':
      command     => $kinit_cmd,
      environment => [ "IPA_ADMIN_PASS=${admin_pass}" ],
      path        => ['/bin', '/usr/bin'],
      notify      => Ipa::Helpers::Flushcache["server_${::fqdn}"],
    }

    ~> exec { "automount_map_home_${::fqdn}":
      command     => $map_home_cmd,
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
    }

    ~> exec { "automount_key_home_${::fqdn}":
      command     => $key_home_cmd,
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
    }

    ~> exec { "automount_key_master_${::fqdn}":
      command     => $key_master_cmd,
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
    }

    ~> exec { 'ipa_config_mod_homedir':
      command     => $config_homedir_cmd,
      path        => ['/bin', '/usr/bin'],
      refreshonly => true,
    }

    exec { 'autofs_create_automount_home_dir':
      command => "mkdir -p ${automount_home_dir}",
      path    => ['/bin', '/usr/bin'],
      creates => $automount_home_dir,
    }
  }

  # Ensure nsswitch is configured for SSSD
  file_line { '/etc/nsswitch.conf':
    ensure => 'present',
    path   => '/etc/nsswitch.conf',
    line   => 'automount:  files sss',
    match  => '^automount:.*',
    notify => Ipa::Helpers::Flushcache["server_${::fqdn}"],
  }

  # Set puppet fact for autofs installed
  facter::fact { 'autofs_installed':
    value => true,
  }

}
