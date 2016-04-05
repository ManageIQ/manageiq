require_migration

describe SetCorrectStiTypeOnCloudSubnet do
  let(:cloud_subnet_stub)      { migration_stub(:CloudSubnet) }
  let(:cloud_network_stub)     { migration_stub(:CloudNetwork) }

  let!(:empty_cloud_subnet)    { cloud_subnet_stub.create! }

  let!(:private_cloud_network) { cloud_network_stub.create!(:type => described_class::CLOUD_PRIVATE_CLASS) }
  let!(:private_cloud_subnet)  { cloud_subnet_stub.create!(:cloud_network_id => private_cloud_network.id) }

  let!(:public_cloud_network)  { cloud_network_stub.create!(:type => described_class::CLOUD_PUBLIC_CLASS) }
  let!(:public_cloud_subnet)   { cloud_subnet_stub.create!(:cloud_network_id => public_cloud_network.id) }

  migration_context :up do
    it "migrates a series of representative row" do
      migrate

      expect(empty_cloud_subnet.reload.type).to eq("CloudSubnet")
      expect(private_cloud_subnet.reload.type).to eq(described_class::CLOUD_SUBNET)
      expect(public_cloud_subnet.reload.type).to eq(described_class::CLOUD_SUBNET)
    end
  end

  migration_context :down do
    it "migrates a series of representative row" do
      private_cloud_subnet.type = described_class::CLOUD_SUBNET
      private_cloud_subnet.save!

      public_cloud_subnet.type = described_class::CLOUD_SUBNET
      public_cloud_subnet.save!

      migrate

      expect(private_cloud_subnet.reload.type).to be_nil
      expect(public_cloud_subnet.reload.type).to be_nil
    end
  end
end
