#
class ipa::install::client (
  String             $automount_home_dir    = $ipa::automount_home_dir,
  Boolean            $client_configure_ntp  = $ipa::configure_ntp,
  String             $client_ensure         = $ipa::params::ipa_client_package_ensure,
  Boolean            $client_install_ldap   = $ipa::client_install_ldaputils,
  String             $client_package_name   = $ipa::params::ipa_client_package_name,
  Boolean            $client_trust_dns      = $ipa::trust_dns,
  String             $domain_name           = $ipa::domain,
  String             $ldap_package_name     = $ipa::params::ldaputils_package_name,
  Boolean            $make_homedir          = $ipa::mkhomedir,
  Sensitive[String]  $principal_pass        = $ipa::final_domain_join_password,
  String             $principal_user        = $ipa::final_domain_join_principal,
  String             $sssd_package_name     = $ipa::params::sssd_package_name,
) {
  package{ 'ipa-client':
    ensure => $client_ensure,
    name   => $client_package_name,
  }

  if $client_install_ldap {
    package { $ldap_package_name:
      ensure => present,
    }
  }

  if $client_trust_dns {
    $client_dns_opts = '--ssh-trust-dns'
  } else {
    # Fix is not using DNS for host resolution
    $client_dns_opts = "--server=${ipa::ipa_master_fqdn}"
  }

  if $client_configure_ntp {
    $client_ntp_opts = ''
  } else {
    $client_ntp_opts = '--no-ntp'
  }

  # Build client install command
  $client_install_cmd = @("EOC"/)
    ipa-client-install \
    --domain=${domain_name} \
    --principal="${principal_user}" \
    --password=\$IPA_JOIN_PASSWORD \
    ${client_dns_opts} \
    ${client_ntp_opts} \
    --unattended
    | EOC

  if $client_ensure == 'present' {
    exec { "client_install_${::hostname}":
      command     => $client_install_cmd,
      environment => [ "IPA_JOIN_PASSWORD=${principal_pass.unwrap}" ],
      path        => ['/bin', '/sbin', '/usr/sbin'],
      timeout     => 0,
      unless      => "cat /etc/ipa/default.conf | grep -i \"${domain_name}\"",
      creates     => '/etc/ipa/default.conf',
      logoutput   => 'on_failure',
      provider    => 'shell',
      notify      => Ipa::Helpers::Flushcache["server_${::fqdn}"],
    }

    # This will customize the sssd.conf file for EMS specifics.
    # NOTE: Needed to place outside of master loop to allow for IPA install to
    #       create original version and then update it on the master server.
    file { '/etc/sssd/sssd.conf':
      ensure  => file,
      content => template('ipa/sssd.conf.erb'),
      mode    => '0600',
      require => [
        Package[$sssd_package_name],
        Exec["client_install_${::hostname}"],
      ],
      notify  => Ipa::Helpers::Flushcache["server_${::fqdn}"],
    }
  }

  if $automount_home_dir != undef {
    exec { 'client_create_automount_home_dir':
      command => "mkdir -p ${automount_home_dir}",
      path    => ['/bin', '/usr/bin'],
      creates => $automount_home_dir,
    }

    # Update nsswitch if autofs enabled.
    ~> file_line { '/etc/nsswitch.conf':
      path   => '/etc/nsswitch.conf',
      line   => 'automount:  files sss',
      match  => '^automount: ',
      notify => Ipa::Helpers::Flushcache["server_${::fqdn}"],
    }

    # Required for cross-domain lookups (example, AD joined hosts) lookup.
    ~> file_line { 'krb5.conf_dns_realm':
      path  => '/etc/krb5.conf',
      line  => '  dns_lookup_realm = true',
      match => '^  dns_lookup_realm =',
    }

    ~> file_line { 'krb5.conf_dns_kdc':
      path  => '/etc/krb5.conf',
      line  => '  dns_lookup_kdc = true',
      match => '^  dns_lookup_kdc =',
    }
  }

}
