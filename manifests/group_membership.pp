# @summar Manages an IPA group membership
define ipa::group_membership (
  String $ensure                           = 'present',
  String $group                            = $name,
  Enum['inclusive', 'minimum'] $membership = 'minimum',
  Optional[Array[String]] $groups          = undef,
  Optional[Array[String]] $users           = undef,
  Optional[Array[String]] $services        = undef,
  String $api_username                     = $ipa::admin_user,
  String $api_password                     = $ipa::admin_password,
) {
  ipa_group_membership { $title:
    ensure       => $ensure,
    name         => $name,
    group        => $group,
    groups       => $groups,
    users        => $users,
    services     => $services,
    api_username => $api_username,
    api_password => $api_password,
  }
}
