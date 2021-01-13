require 'fixtures/modules/firewalld/lib/puppet/provider/firewalld'

def mock_firewalld
  before(:each) do
    # mock out exec resource for firewalld::reload
    output = mock
    output.stubs(:exitstatus).returns(0)
    Puppet::Util::Execution.stubs(:execute).returns(output)

    # mock out firewalld so we don't get prompts
    Puppet::Provider::Firewalld.any_instance.stubs(:running).returns(:true) # rubocop:disable RSpec/AnyInstance
  end
end
