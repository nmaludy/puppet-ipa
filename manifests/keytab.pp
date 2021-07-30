# Retrieves a Kerberos Service keytab and stores it in a local file.
define ipa::keytab (
  String $principal = $name,
  Optional[String] $file = undef,
  Optional[String] $server = undef,
  Optional[String] $username = undef,
  Optional[String] $password = undef,
  # default is retrieve, otherwise keytab will overwrite everyone else
  Enum['retrieve', 'create'] $action = 'retrieve',
  Boolean $file_manage       = true,
  String  $owner             = 'root',
  String  $group             = 'root',
  String  $mode              = '0600',
) {
  include ipa
  $_file = pick($file, $ipa::keytab_default)
  $_server = pick($server, $ipa::ipa_master_fqdn)
  if $ipa::ipa_role == 'client' {
    $_username = pick($username, $ipa::domain_join_principal)
    $_password = pick($password, $ipa::domain_join_password)
  }
  else {
    $_username = pick($username, $ipa::admin_user)
    $_password = pick($password, $ipa::admin_password)
  }

  $_ldap_domain = $ipa::domain.split(/\./).map |$item| { "dc=${item}" }.join(',')
  $_username_dn = "uid=${_username},cn=users,cn=accounts,${_ldap_domain}"

  case $action {
    # when retrieving keytab, need to pass in -r
    'retrieve': { $action_args = '-r' }
    'create': { $action_args = '' }
    default: { $action_args = '' }
  }

  exec { "ipa-getkeytab -p ${principal} -k ${_file}":
    command     => "ipa-getkeytab ${action_args} -s ${_server} -p ${principal} -k ${_file} -D ${_username_dn} -w \"\$IPA_PASSWORD\"",
    unless      => "klist -k ${_file} | grep -q '${principal}'",
    environment => [ "IPA_PASSWORD=${_password}" ],
    path        => ['/usr/bin', '/bin', '/usr/sbin', '/sbin'],
  }

  if $file_manage {
    file { $_file:
      ensure    => file,
      owner     => $owner,
      group     => $group,
      mode      => $mode,
      subscribe => Exec["ipa-getkeytab -p ${principal} -k ${_file}"],
    }
  }
}
