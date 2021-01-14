require 'fixtures/modules/firewalld/lib/puppet/provider/firewalld'

def mock_firewalld
  before(:each) do
    # mock out exec resource for firewalld::reload
    output = double
    allow(output).to receive(:exitstatus).and_return(0)

    allow_any_instance_of(Puppet::Util::Execution).to receive(:execute).and_return(output) # rubocop:disable RSpec/AnyInstance

    # mock out firewalld so we don't get prompts
    allow_any_instance_of(Puppet::Provider::Firewalld).to receive(:running).and_return(:true) # rubocop:disable RSpec/AnyInstance
  end
end
