#
class ipa::install::sssd (
  String  $sssd_package_name = $ipa::params::sssd_package_name,
  String  $sssd_ipa_package_name = $ipa::params::sssd_ipa_package_name,
) inherits ipa::params {
  package { [$sssd_package_name, $sssd_ipa_package_name]:
    ensure => present,
  }

  # Copy flush sssd cache to host
  file { "flush_sssd_cache_${$facts['fqdn']}":
    ensure  => file,
    path    => '/root/flush_sssd_cache.sh',
    content => file('ipa/flush_sssd_cache.sh'),
    mode    => '0750',
    owner   => 'root',
    group   => 'root',
  }
}
