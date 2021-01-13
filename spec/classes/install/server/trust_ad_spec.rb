require 'spec_helper'

describe 'ipa::install::server::trust_ad' do
  mock_firewalld

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts.merge(fqdn: 'hostname.domain.tld') }

      let(:pre_condition) do
        <<-EOS
        class { 'ipa':
          ad_groups            => ['linux_users', 'linux_admins'],
          ad_trust_admin       => 'trustadmin@ad.domain.tld',
          ad_trust_password    => 'TrustPassword123',
          ad_trust_realm       => 'ad.domain.tld',
          admin_user           => 'admin',
          admin_password       => 'AdminPassword123',
          domain               => 'ipa.domain.tld',
          domain_join_password => 'IpaJoin123',
          ds_password          => 'DsPassword123',
          ipa_role             => 'master',
          ipa_master_fqdn      => 'ipa01.ipa.domain.tld',
        }
        EOS
      end

      let(:config_ipa_ldap) do
        <<-'EOS'
#!/bin/bash

# DESCRIPTION:  This script will enable LDAP integration with IPA if parameters
#               are configured to the environment.

# AD Domain for users
ad_domain=ad.domain.tld
# An array of LDAP groups to configure within IPA
ad_groups=(linux_users linux_admins)
log='ipa_ldap_config.log'

# Start of main
echo "Start IPA Configure @ $(date +%F)" > "$log"

klist -s
if [[ $? -gt 0 ]]; then
  echo "Enter the IPA admin password (NOTE: password is masked)"
  kinit admin
fi

ipa trust-show $ad_domain | tee -a "$log"
if [[ $? -gt 0 ]]; then
  cat <<EOF | tee -a "$log"

RESOLUTION: Run the following command:

  $ ipa trust-add <AD_DOMAIN> --admin=<AD_ADMIN_USER> --password

...and then rerun this script.
EOF
  exit 2
fi

if [[ -f /etc/samba/samba.keystore ]]; then
  sudo yum -y install ipa-server-trust-ad samba samba-client

  echo 'AdminPassword123' | kinit admin
  ipa-adtrust-install ad.domain.tld --admin=trustadmin@ad.domain.tld -U 2>&1| tee -a "$log"
fi

# Create IPA groups
i=0
while (( i < ${#ad_groups[*]} )); do
  # Create external LDAP group
  echo -e "\n> ipa group-add --desc='Corporate AD User Group' ${ad_groups[$i]}_ext --external" | tee -a "$log"
  ipa group-add ${ad_groups[$i]}_ext \
    --desc='Corporate AD User Group' \
    --external 2>&1| tee -a "$log"

  # Create POSIX group for LDAP group
  echo -e "\n> ipa group-add --desc='POSIX User Group' ${ad_groups[$i]}_psx" | tee -a "$log"
  ipa group-add ${ad_groups[$i]}_psx \
    --desc='POSIX User Group' 2>&1| tee -a "$log"

  # Link AD groupname to external group
  echo -e "\n> ipa -n group-add-member ${ad_groups[$i]}_ext --external ${ad_groups[$i]}@${ad_domain}" |\
    tee -a "$log"
  ipa -n group-add-member ${ad_groups[$i]}_ext \
    --external ${ad_groups[$i]}@${ad_domain} 2>&1| tee -a "$log"

  # Add external group to POSIX group
  echo -e "\n> ipa group-add-member ${ad_groups[$i]}_psx --groups ${ad_groups[$i]}_ext" | tee -a "$log"
  ipa group-add-member ${ad_groups[$i]}_psx \
    --groups ${ad_groups[$i]}_ext 2>&1| tee -a "$log"

  # Create hbac rule for LDAP group
  echo -e "\n> ipa hbacrule-add ${ad_groups[$i]}_hbac --hostcat='all' --servicecat='all'" | tee -a "$log"
  ipa hbacrule-add ${ad_groups[$i]}_hbac \
    --hostcat='all' \
    --servicecat='all' 2>&1| tee -a "$log"

  # Add LDAP group to hbac rule
  echo -e "\n> ipa hbacrule-add-user ${ad_groups[$i]}_hbac --groups=${ad_groups[$i]}_psx" | tee -a "$log"
  ipa hbacrule-add-user ${ad_groups[$i]}_hbac \
    --groups=${ad_groups[$i]}_psx 2>&1| tee -a "$log"

  # Create sudo rule for LDAP group
  echo -e "\n> ipa sudorule-add ${ad_groups[$i]}_sudo --hostcat='all' --cmdcat='all' \\
    --runasusercat='all' --runasgroupscat='all'" | tee -a "$log"
  ipa sudorule-add ${ad_groups[$i]}_sudo \
    --hostcat='all' \
    --cmdcat='all' \
    --runasusercat='all' \
    --runasgroupcat='all' 2>&1| tee -a "$log"

  # Add LDAP group to sudo rule
  echo -e "\n> ipa sudorule-add-user ${ad_groups[$i]}_sudo --groups=${ad_groups[$i]}_psx" | tee -a "$log"
  ipa sudorule-add-user ${ad_groups[$i]}_sudo \
    --groups=${ad_groups[$i]}_psx 2>&1| tee -a "$log"

  ((i++))

done

echo "End IPA Configure @ $(date +%F)" >> "$log"
EOS
      end

      let(:id_override) do
        <<-'EOS'
#!/bin/bash

userID=$1
ad_domain=ad.domain.tld
homeDir="/home/ipa/${ad_domain}/${userID}"
sshKey="$(cat "${homeDir}/.ssh/id_rsa.pub")"

if [[ -z $userID ]]; then
  echo "Must supply user ID to process (user.name)"
  exit 1
fi

klist -s
if [[ $? -gt 0 ]]; then
  echo "Enter the IPA admin password (NOTE: password is masked)"
  kinit admin
fi

ipa idoverrideuser-add "Default Trust View" "${userID}@${ad_domain}" \
  --shell='/bin/bash' \
  --homedir="$homeDir" \
  --sshpubkey="$sshKey"
EOS
      end

      it do
        is_expected.to compile
      end
      it do
        is_expected.to contain_file('/root/01_config_ipa_ldap.sh')
          .with('ensure'  => 'file',
                'mode'    => '0750',
                'owner'   => 'root',
                'group'   => 'root',
                'content' => config_ipa_ldap)
      end
      it do
        is_expected.to contain_file('/root/02_id_override.sh')
          .with('ensure'  => 'file',
                'mode'    => '0750',
                'owner'   => 'root',
                'group'   => 'root',
                'content' => id_override)
      end
    end
  end
end
