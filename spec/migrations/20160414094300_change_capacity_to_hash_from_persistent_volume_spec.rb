require_migration

describe ChangeCapacityToHashFromPersistentVolume do
  let(:persistent_volume_stub) { migration_stub(:PersistentVolume) }

  migration_context :up do
    it "changes capacity to hash" do
      persistent_volume_stub.create!(:capacity => 'storage=10Gi')
      migrate
      expect(persistent_volume_stub.first.capacity).to eq(:storage => 10737418240)
    end

    it "changes capacity to hash with multiple values" do
      persistent_volume_stub.create!(:capacity => 'storage=10Gi,foo=10')
      migrate
      expect(persistent_volume_stub.first.capacity).to eq(:storage => 10737418240, :foo => 10)
    end

    it "changes capacity to hash with nil value" do
      persistent_volume_stub.create!(:capacity => nil)
      migrate
      expect(persistent_volume_stub.first.capacity).to eq(nil)
    end
  end

  migration_context :down do
    it "changes capacity to string" do
      persistent_volume_stub.create!(:capacity => {:storage => 10737418240})
      migrate
      expect(persistent_volume_stub.first.capacity).to eq('storage=10737418240')
    end

    it "changes capacity to string from multi value hash" do
      persistent_volume_stub.create!(:capacity => {:storage => 10737418240, :foo => 10})
      migrate
      expect(persistent_volume_stub.first.capacity).to eq('storage=10737418240,foo=10')
    end

    it "changes capacity to string from nil value" do
      persistent_volume_stub.create!(:capacity => nil)
      migrate
      expect(persistent_volume_stub.first.capacity).to eq(nil)
    end

    it "changes capacity to string from empty hash" do
      persistent_volume_stub.create!(:capacity => {})
      migrate
      expect(persistent_volume_stub.first.capacity).to eq(nil)
    end
  end
end
