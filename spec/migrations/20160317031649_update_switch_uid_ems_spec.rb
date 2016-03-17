require_migration

describe UpdateSwitchUidEms do
  migration_context :up do
    let(:switch_stub) { migration_stub(:Switch) }
    it 'Switch uid_ems gets updated' do
      uid_ems = "vswtich0"
      host_id = 101
      switch = switch_stub.create!(:uid_ems => uid_ems, :host_id => host_id)

      migrate

      switch.reload
      expect(switch.uid_ems).to eq("#{host_id}|#{uid_ems}")
    end
  end

  migration_context :down do
    let(:switch_stub) { migration_stub(:Switch) }
    it 'Rollback switches.uid_ems successfully' do
      uid_ems = "vswtich0"
      host_id = 101
      switch = switch_stub.create!(:uid_ems => "#{host_id}|#{uid_ems}")

      migrate

      switch.reload
      expect(switch.uid_ems).to eq(uid_ems.to_s)
    end

    it "Rollback switches.uid_ems fails due to missing '|'" do
      uid_ems = "vswtich0"
      host_id = 101
      switch_stub.create!(:uid_ems => "#{host_id}#{uid_ems}")

      expect do
        migrate
      end.to raise_error RuntimeError, "Expected '|' not found in uid_ems"
    end
  end
end
