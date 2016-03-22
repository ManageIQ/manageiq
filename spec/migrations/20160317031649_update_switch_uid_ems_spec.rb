require_migration

describe UpdateSwitchUidEms do
  before(:each) do
    @ems_guid = 'FFFF'
    @uid_ems = 'vswtich0'
    @host_ref = 'host-101'
  end

  migration_context :up do
    let(:switch_stub) { migration_stub(:Switch) }
    let(:host_stub) { migration_stub(:Host) }
    let(:ems_stub) { migration_stub(:ExtManagementSystem) }
    it 'Switch uid_ems gets updated' do
      ems = ems_stub.create!(:guid => @ems_guid)
      host = host_stub.create!(:ems_ref => @host_ref, :ems_id => ems.id)
      switch = switch_stub.create!(:uid_ems => @uid_ems, :host_id => host.id)
      expect(switch.uid_ems).to eq(@uid_ems)

      migrate

      switch.reload
      expect(switch.uid_ems).to eq("#{@ems_guid}|#{@host_ref}|#{@uid_ems}")
    end
  end

  migration_context :down do
    let(:switch_stub) { migration_stub(:Switch) }
    it 'Rollback switches.uid_ems successfully' do
      switch = switch_stub.create!(:uid_ems => "#{@ems_guid}|#{@host_ref}|#{@uid_ems}")

      migrate

      switch.reload
      expect(switch.uid_ems).to eq(@uid_ems)
    end

    it "Rollback switches.uid_ems fails due to missing '|'" do
      switch_stub.create!(:uid_ems => "#{@host_ref}#{@uid_ems}")

      expect do
        migrate
      end.to raise_error RuntimeError, "Expected '|' not found in uid_ems"
    end
  end
end
