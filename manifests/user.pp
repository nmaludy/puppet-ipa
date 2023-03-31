# @summary Creates a user in IPA and manages their home directory on an NFS share
#
# @param [String] initial_password
#   Password to set on the user when creating them. Initial creation will force a password
#   change when the user logs in the first time.
#   Passwords are not managed going forward.
#
# @param [String] ensure
#   'present' (create the user) or 'absent' (delete the user)
#
# @param [String] first_name
#   First name for the user's account. (display only)
#
# @param [String] last_name
#   Last name for the user's account. (display only)
#
# @param [Boolean] manage_home_dir
#   Ensure the user's home directory exists
#
# @param [String] home_dir_base
#   Directory on the IPA server where the user's home dir should be created.
#   The username will be appended to this to create the absolute path for the user's home
#   directory creation.
#
# @param [String] home_dir_mode
#   File mode of the user's home directory
#
# @param [Boolean] manage_etc_skel
#   Ensure the files in /etc/skel are present in the user's home directory.
#   We set 'replace => false' on these File instances so that any user modifications
#   are not overwritten by Puppet.
#   However, when managing we do ensure all of the files exist and have the proper
#   owner and group.
#
# @param [Boolean] manage_dot_ssh
#   Ensure the ~/.ssh directory exists, has the proper owner/group/mode.
#
# @param [Optional[Array[String]]] sshpubkeys
#   Array of SSH public keys to set on the user's account.
#   The format of each key should be exactly like you see it in your id_xxx.pub file.
#   note: if set, this will purge all keys that do not match.
#
# @param [String] api_username
#   The user is created by communicating with the FreeIPA API. This is the username
#   to use for logging in to the API. This user _must_ be an admin.
#
# @param [String] api_password
#   Password for FreeIPA API access.
#
# @example Basic usage
#   ipa::user { 'testuser':
#     ensure           => present,
#     initial_password => 'abc123',
#     home_dir_base    => '/srv/nfs/home',
#   }
#
# @example Managing a user's SSH keys
#   ipa::user { 'testuser':
#     ensure           => present,
#     initial_password => 'abc123',
#     home_dir_base    => '/srv/nfs/home',
#     sshpubkeys       => [
#       'ssh-rsa ACDSFDSFdsf= user@domain.tld',
#     ]
#   }
#
# @example Adding a user to groups, this auto-creates ipa::group_membership instances
#   ipa::user { 'testuser':
#     ensure           => present,
#     initial_password => 'abc123',
#     home_dir_base    => '/srv/nfs/home',
#     groups           =>
#   }
#
# @example Deleting a user
#   ipa::user { 'testuser':
#     ensure           => absent,
#     initial_password => 'abc123',
#   }
define ipa::user (
  String $initial_password,
  String $ensure                      = 'present',
  String $first_name                  = $name,
  String $last_name                   = $name,
  Boolean $enable                     = true,
  Optional[String] $login_shell       = undef,
  Optional[String] $mail              = undef,
  Optional[String] $job_title         = undef,
  Optional[Hash] $ldap_attributes     = undef,
  Boolean $manage_home_dir            = true,
  String $home_dir_base               = '',
  String $home_dir_mode               = '0700',
  String $home_dir                    = "${home_dir_base}/${name}",
  Boolean $manage_etc_skel            = true,
  Boolean $manage_dot_ssh             = true,
  Optional[Array[String]] $sshpubkeys = undef,
  Optional[Array[String]] $groups     = undef,
  String $api_username                = $ipa::admin_user,
  String $api_password                = $ipa::admin_password,
) {
  ipa_user { $title:
    ensure           => $ensure,
    enable           => $enable,
    name             => $name,
    initial_password => $initial_password,
    first_name       => $first_name,
    last_name        => $last_name,
    sshpubkeys       => $sshpubkeys,
    homedirectory    => $home_dir,
    login_shell      => $login_shell,
    mail             => $mail,
    job_title        => $job_title,
    ldap_attributes  => $ldap_attributes,
    api_username     => $ipa::admin_user,
    api_password     => $ipa::admin_password,
  }

  $_file_ensure = $ensure ? {
    'absent' => 'absent',
    default  => undef,
  }
  if $manage_home_dir {
    file { $home_dir:
      ensure  => pick($_file_ensure, 'directory'),
      owner   => $name,
      group   => $name,
      mode    => $home_dir_mode,
      force   => true,
      require => Ipa_user[$name],
    }
  }

  # copy all files in /etc/skel/. over to home directory
  if $manage_etc_skel {
    $facts['ipa_etc_skel_files'].each |$file_path, $file_props| {
      file { "${home_dir}/${file_props['local_path']}":
        ensure  => pick($_file_ensure, $file_props['ensure']),
        owner   => $name,
        group   => $name,
        source  => $file_path,
        mode    => undef,
        replace => false,
        require => Ipa_user[$name],
      }
    }
  }

  # create user's ~/.ssh directory and set proper permissions
  if $manage_dot_ssh {
    file { "${home_dir}/.ssh":
      ensure  => pick($_file_ensure, 'directory'),
      owner   => $name,
      group   => $name,
      mode    => '0700',
      force   => true,
      require => Ipa_user[$name],
    }
  }

  # create group memberships for this user
  if $groups {
    $groups.each |$grp| {
      ipa::group_membership { "${grp}:${title}":
        ensure       => $ensure,
        group        => $grp,
        users        => [$name],
        api_username => $api_username,
        api_password => $api_password,
      }
    }
  }
}
