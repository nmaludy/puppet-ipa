#
class ipa::install::sssd (
  String  $sssd_package_name  = $ipa::params::sssd_package_name,
) {

  package { $sssd_package_name:
    ensure => present,
    notify => File['/etc/sssd/sssd.conf'],
  }

  # Copy flush sssd cache to host
  file { "flush_sssd_cache_${::fqdn}":
    ensure  => file,
    path    => '/root/flush_sssd_cache.sh',
    content => template('ipa/flush_sssd_cache.sh.erb'),
    mode    => '0750',
    owner   => 'root',
    group   => 'root',
    require => Package[$sssd_package_name],
  }

}
