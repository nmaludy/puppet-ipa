# ipa Puppet module
[![Build Status](https://github.com/EncoreTechnologies/puppet-ipa/src/master/)](https://github.com/EncoreTechnologies/puppet-ipa/src/master/)

## Overview

This module will install and configure IPA servers, replicas, and clients. This module was forked from huit-ipa, 
and refactored with a focus on simplicity and ease of use. It has been further refactored to support Red Hat installations only.

The following features work great:
- Creating a domain.
- Adding IPA server replicas.
- Autofs configuration.
- Trust-ad join.
- Joining clients.
- Firewalld management.

The following features were stripped out and are currently unavailable:
- Sudo rule management.
- Host management (beyond simple clinet domain joins).
- Host joins via one time passwords.
- Dns zone management (beyond creating an initial zone).
- Admin configuration
- Web configuration

## Dependencies
This module requires:
- [puppetlabs/stdlib](https://forge.puppetlabs.com/puppetlabs/stdlib) >= 4.13.0.
- [crayfishx/firewalld](https://forge.puppet.com/crayfishx/firewalld) >= 3.0.0.

## Usage

### Example usage:

Creating an IPA master, with ad-trust to corp.domain.com.
```puppet
  class { '::ipa':
    ad_domain            => 'corp.domain.com',
    ad_groups            => ['linux_admins','linux_users'],
    ad_trust_admin       => 'ad_admin@domain.com',
    ad_trust_password    => 'ad_admin_password',
    ad_trust_realm       => 'corp.domain.com',
    admin_password       => 'ChangeM3!',
    automount_home_dir   => "/home/ipa/${ad_domain}",
    automount_home_share => 'nfs01.corp.domain.com:/srv/nfs/homes/&',
    domain               => 'ipa.corp.domain.com',
    ds_password          => 'ChangeM3!',
    install_ipa_client   => false,
    ipa_master_fqdn      => $facts['fqdn'],
    ipa_role             => 'master',
    sssd_debug_level     => '3',
  }
```

Adding a replica:
```puppet
  class { '::ipa':
    admin_password       => 'ChangeM3!',
    automount_home_dir   => '/home/ipa/corp.domain.com',
    configure_replica_ca => true,
    domain               => 'ipa.corp.domain.com',
    domain_join_password => 'ChangeM3!',
    ipa_master_fqdn      => 'ipa01.corp.domain.com',
    ipa_role             => 'replica',
    sssd_debug_level     => '3',
  }
```

Adding a client:
```puppet
  class { '::ipa':
    automount_home_dir   => '/home/ipa/corp.domain.com',
    domain               => 'ipa.corp.domain.com',
    domain_join_password => 'ChangeM3!',
    ipa_master_fqdn      => 'ipa01.corp.domain.com',
    ipa_role             => 'client',
  }
```

### Mandatory Parameters

#### `domain`
Mandatory. The name of the IPA domain to create or join.

#### `ipa_role`
Mandatory. What role the node will be. Options are 'master', 'replica', and 'client'.

#### `admin_password`
Mandatory if `ipa_role` is set as 'Master' or 'Replica'.
Password which will be assigned to the IPA account named 'admin'.

#### `ds_password`
Mandatory if `ipa_role` is set as 'Master'.
Password which will be passed into the ipa setup's parameter named "--ds-password".

### Optional Parameters

#### `configure_dns_server`
If true, then the parameter '--setup-dns' is passed to the IPA server installer.
Also, triggers the install of the required dns server packages.

#### `configure_replica_ca`
If true, then the parameter '--setup-ca' is passed to the IPA replica installer.

#### `configure_ntp`
If false, then the parameter '--no-ntp' is passed to the IPA server installer.

#### `custom_dns_forwarders`
Each element in this array is prefixed with '--forwarder ' and passed to the IPA server installer.

#### `domain_join_principal`
The principal (usually username) used to join a client or replica to the IPA domain.

#### `domain_join_password`
The password for the domain_join_principal.

#### `enable_hostname`
If true, then the parameter '--hostname' is populated with the parameter 'ipa_server_fqdn'
and passed to the IPA installer.

#### `enable_ip_address`
If true, then the parameter '--ip-address' is populated with the parameter 'ip_address'
and passed to the IPA installer.

#### `fixed_primary`
If true, then the parameter '--fixed-primary' is passed to the IPA installer.

#### `idstart`
From the IPA man pages: "The starting user and group id number".

#### `install_autofs`
If true, then the autofs packages are installed.

#### `install_epel`
If true, then the epel repo is installed. The epel repo is usually required for sssd packages.

#### `install_kstart`
If true, then the kstart packages are installed.

#### `install_sssdtools`
If true, then the sssdtools packages are installed.

#### `install_ipa_client`
If true, then the IPA client packages are installed if the parameter 'ipa_role' is set to 'client'.

#### `install_ipa_server`
If true, then the IPA server packages are installed if the parameter 'ipa_role' is not set to 'client'.

#### `install_sssd`
If true, then the sssd packages are installed.

#### `ipa_master_fqdn`
FQDN of the server to use for a client or replica domain join.

#### `manage_host_entry`
If true, then a host entry is created using the parameters 'ipa_server_fqdn' and 'ip_address'.

#### `mkhomedir`
If true, then the parameter '--mkhomedir' is passed to the IPA client installer.

#### `no_ui_redirect`
If true, then the parameter '--no-ui-redirect' is passed to the IPA server installer.

#### `realm`
The name of the IPA realm to create or join (UPPERCASE).


## Limitations

This module has only been tested on RHEL 7.

## Testing
A vagrantfile is provided for easy testing.

Steps to get started:
 1. Install vagrant.
 1. Install virtualbox.
 1. Clone this repo.
 1. Run `vagrant up` in a terminal window from the root of the repo.
 1. Open a browser and navigate to `https://localhost:8440`.
 Log in with username `admin` and password `vagrant123`.

## License
jpuskar/puppet-easy_ipa forked from:
huit/puppet-ipa - Puppet module that can manage an IPA master, replicas and clients.

    Copyright (C) 2013 Harvard University Information Technology
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
