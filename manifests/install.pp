#
# DESCRIPTION: This module will install and configure IPA server based on the
#              role of the client.  The first run of this may take up to 15
#              minutes to complete on the master or replica servers, be patient.
#

class ipa::install (
  String     $auto_home_share     = $ipa::automount_home_share,
  String     $auto_location       = $ipa::automount_location,
  String     $autofs_package      = $ipa::params::autofs_package_name,
  Boolean    $configure_dns       = $ipa::final_configure_dns_server,
  Boolean    $install_ad_trust    = $ipa::install_trust_ad,
  Boolean    $install_autofs      = $ipa::install_autofs,
  Boolean    $install_epel        = $ipa::install_epel,
  Boolean    $install_ipa_server  = $ipa::install_ipa_server,
  Boolean    $install_sssd        = $ipa::install_sssd,
  Boolean    $install_sssd_tools  = $ipa::install_sssdtools,
  String     $ipa_role            = $ipa::ipa_role,
  String     $sssd_package_name   = $ipa::params::sssd_package_name,
  String     $sssd_tools_package  = $ipa::params::sssdtools_package_name,
) {

  # Do we want to do this or rely on Satellite repository?
  if $install_epel and $facts['os']['family'] == 'RedHat' {
    contain epel
  }

  # Configure firewall rules if enabled.
  if $ipa_role == 'master' or $ipa_role == 'replica' {
    case $facts['os']['family'] {
      'RedHat': {
        case $facts['os']['release']['major'] {
          /(7)/, /(8)/: {}
          default: {
            fail("ERROR: Server can only be installed on RHEL 7+, \
            not RHEL version: ${facts['os']['full']}")
          }
        }
      }
      default: {
        fail("ERROR: Server can only be installed on RHEL 7+, \
        not on operating system: ${facts['os']['family']}")
      }
    }

    contain ipa::helpers::firewalld
  }

  if $install_sssd {
    contain ipa::install::sssd
  }

  if $install_sssd_tools {
    package { $sssd_tools_package:
      ensure => present,
    }
  }

  # install AutoFS here so both clients and servers get the package if they ask for it
  # otherwise we would have to put this in both server and client manifests
  if $install_autofs {
    ensure_resource('package', $autofs_package, { 'ensure' => 'present' })
  }

  # Install client if setting up replica server
  if $ipa_role == 'client' or $ipa_role == 'replica' {
    contain ipa::install::client

    # This will customize the sssd.conf file for EMS specifics.
    # NOTE: Needed to place outside of master loop to allow for IPA install to
    #       create original version and then update it on the master server.
    file { '/etc/sssd/sssd.conf':
      content => template('ipa/sssd.conf.erb'),
      mode    => '0600',
      require => Package[$sssd_package_name],
      notify  => Ipa::Helpers::Flushcache["server_${::fqdn}"],
    }
  }

  if $ipa_role == 'master' or $ipa_role == 'replica' {
    if $configure_dns {
      $dns_packages = [
        'ipa-server-dns',
        'bind-dyndb-ldap',
      ]
      package{$dns_packages:
        ensure => present,
      }
    }

    # Call server install mainfest
    if $install_ipa_server {
      contain ipa::install::server
    }

    # Call trust_ad install manifest
    if $install_ad_trust == true and $facts['trust_ad'] == undef {
      contain ipa::install::server::trust_ad
    }

    # Call autofs install mainfest
    if $ipa_role == 'master' {
      if $install_autofs {
        class { 'ipa::install::server::autofs':
          automount_home_share => $auto_home_share,
          automount_location   => $auto_location,
        }
        contain ipa::install::server::autofs
      }
    }
  }

  # Define helper
  ipa::helpers::flushcache { "server_${::fqdn}": }

}
