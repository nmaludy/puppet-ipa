#
# == Class: ipa::install::client::manual
#
# "Manual" configuration of hosts which don't have the freeipa-client package
#
class ipa::install::client::manual
{

  # Generate LDAP base DN from the domain (e.g. dc=vagrant,dc=example,dc=lan)
  $ldap_base_temp = regsubst($::ipa::domain, '\.',',dc=', 'G')
  $ldap_base = regsubst($ldap_base_temp, '^', 'dc=')

  File {
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

  file { '/etc/krb5.conf':
    content => template('ipa/krb5.conf.erb'),
  }

  file { '/etc/ldap/ldap.conf':
    content => template('ipa/ldap.conf.erb'),
  }

  file { '/etc/sssd/sssd.conf':
    content => template('ipa/sssd.conf.erb'),
    mode    => '0600',
  }

  package { 'krb5-user':
    ensure => 'present',
  }
}
