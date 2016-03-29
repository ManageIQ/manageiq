require_migration

describe RemoveHostIdFromSwitch do
  before(:each) do
    @host = host_stub.create!
    @switch1 = switch_stub.create!(:hosts => [@host])
    @switch2 = switch_stub.create!(:hosts => [@host])
  end

  migration_context :up do
    let(:host_stub) { migration_stub(:Host) }
    let(:switch_stub) { migration_stub(:Switch) }
    it 'Remove column switches.host_id' do
      expect(@switch1).to respond_to('host_id')
      expect(@host.switches.length).to eq 2

      migrate

      @host.reload
      expect(@host.switches.length).to eq 2
      @switch1.reload
      expect(@switch1).not_to respond_to('host_id')
    end
  end

  migration_context :down do
    let(:switch_stub) { migration_stub(:Switch) }
    let(:host_stub) { migration_stub(:Host) }
    let(:host_switches_stub) { migration_stub(:HostSwitch) }
    it 'Move host-to-switch relationship back to switches.host_id' do
      expect(@host.switches.length).to eq 2
      expect(host_switches_stub.count).to eq 2

      migrate

      @host.reload
      expect(@host.switches.length).to eq 2
      expect(switch_stub.where(:host_id => @host.id, :id => @switch1.id).count).to eq 1
      expect(switch_stub.where(:host_id => @host.id, :id => @switch2.id).count).to eq 1
    end
  end
end
