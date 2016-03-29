require_migration

describe MoveSwitchHostToJointable do
  migration_context :up do
    let(:switch_stub) { migration_stub(:Switch) }
    let(:host_stub) { migration_stub(:Host) }
    let(:host_switches_stub) { migration_stub(:HostSwitch) }
    it 'Move host-to-switch relationship to host_switches table' do
      host = host_stub.create!
      switch1 = switch_stub.create!(:host_id => host.id)
      switch2 = switch_stub.create!(:host_id => host.id)

      migrate

      expect(host_switches_stub.count).to eq 2
      expect(host_switches_stub.where(:host_id => host.id, :switch_id => switch1.id).count).to eq 1
      expect(host_switches_stub.where(:host_id => host.id, :switch_id => switch2.id).count).to eq 1
    end
  end
end
