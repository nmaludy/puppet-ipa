# @summar Manages an IPA group
define ipa::group (
  String $ensure                      = 'present',
  Optional[String] $description       = undef,
  Enum['posix', 'non_posix', 'external'] $group_type = 'posix',
  Optional[Integer] $gid              = undef,
  String $api_username                = $ipa::admin_user,
  String $api_password                = $ipa::admin_password,
) {
  ipa_group { $title:
    ensure       => $ensure,
    name         => $name,
    description  => $description,
    group_type   => $group_type,
    api_username => $api_username,
    api_password => $api_password,
  }
}
