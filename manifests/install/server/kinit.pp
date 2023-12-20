# Class to manage kinit as admin user
class ipa::install::server::kinit (
  String $admin_pass = $ipa::admin_password,
  String $admin_user = $ipa::admin_user,
  String $ipa_realm  = $ipa::final_realm,
  Boolean $force     = $ipa::kinit_force,
) inherits ipa {
  ipa_kinit { $admin_user:
    ensure   => present,
    realm    => $ipa_realm,
    password => $admin_pass,
    force    => $force,
  }
}
