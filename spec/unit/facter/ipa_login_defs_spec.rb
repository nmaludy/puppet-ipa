require 'spec_helper'
require 'facter'
require 'facter/ipa_login_defs'

describe 'ipa_login_defs', type: :fact do
  subject(:fact) { Facter.fact(subject) }

  let(:mock_etc_login_defs) do
    str = <<-EOS
#
# Please note that the parameters in this configuration file control the
# behavior of the tools from the shadow-utils component. None of these
# tools uses the PAM mechanism, and the utilities that use PAM (such as the
# passwd command) should therefore be configured elsewhere. Refer to
# /etc/pam.d/system-auth for more information.
#

MAIL_DIR        /var/spool/mail

#
# Min/max values for automatic uid selection in useradd
#
UID_MIN                  1000
UID_MAX                 60000

#
# Min/max values for automatic gid selection in groupadd
#
GID_MIN                  1000
GID_MAX                 60000

# Use SHA512 to encrypt password.
ENCRYPT_METHOD SHA512
EOS
    str.lines
  end

  before :each do
    Facter.clear
  end

  it 'returns a value' do
    # mock the File.readlines and give it some fake output of our file
    expect(File).to receive(:readlines).with('/etc/login.defs').and_return(mock_etc_login_defs)
    expected_fact = {
      'MAIL_DIR' => '/var/spool/mail',
      'UID_MIN' => 1_000,
      'UID_MAX' => 60_000,
      'GID_MIN' => 1_000,
      'GID_MAX' => 60_000,
      'ENCRYPT_METHOD' => 'SHA512',
    }
    expect(Facter.fact(:ipa_login_defs).value).to eq(expected_fact)
  end
end
