require_migration

describe MoveSwitchHostToJointable do
  migration_context :up do
    let(:switch_stub) { migration_stub(:Switch) }
    let(:host_stub) { migration_stub(:Host) }
    let(:hosts_switches_stub) { migration_stub(:HostsSwitches) }
    it 'Move host-to-switch relationship to hosts_switches table' do
      host = host_stub.create!()
      switch1 = switch_stub.create!(:host_id => host.id)
      switch2 = switch_stub.create!(:host_id => host.id)
      expect(host.switches.length).to eq 2

      migrate

      expect(hosts_switches_stub.count).to eq 2
      expect(hosts_switches_stub.where(:host_id => host.id, :switch_id => switch1.id).count).to eq 1
      expect(hosts_switches_stub.where(:host_id => host.id, :switch_id => switch2.id).count).to eq 1
    end
  end
end
