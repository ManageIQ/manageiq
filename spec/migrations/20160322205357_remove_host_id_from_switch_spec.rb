require_migration

describe RemoveHostIdFromSwitch do
  before(:each) do
    @host = host_stub.create!
    @switch1 = switch_stub.create!(:hosts => [@host])
    @switch2 = switch_stub.create!(:hosts => [@host])
  end

  migration_context :down do
    let(:switch_stub) { migration_stub(:Switch) }
    let(:host_stub) { migration_stub(:Host) }
    let(:host_switches_stub) { migration_stub(:HostSwitch) }
    it 'Move host-to-switch relationship back to switches.host_id' do

      migrate

      @host.reload
      expect(@host.switches.length).to eq 2
      expect(switch_stub.where(:host_id => @host.id, :id => @switch1.id).count).to eq 1
      expect(switch_stub.where(:host_id => @host.id, :id => @switch2.id).count).to eq 1
    end
  end
end
