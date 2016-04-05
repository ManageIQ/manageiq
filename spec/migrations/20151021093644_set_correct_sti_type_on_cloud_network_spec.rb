require_migration

describe SetCorrectStiTypeOnCloudNetwork do
  let(:cloud_manager_stub)   { migration_stub(:CloudManager) }
  let(:cloud_network_stub)   { migration_stub(:CloudNetwork) }

  let!(:empty_cloud_network) { cloud_network_stub.create! }

  let!(:ems_cloud)           { cloud_manager_stub.create!(:type => "ManageIQ::Providers::Openstack::CloudManager") }
  let!(:cloud_cloud_network) { cloud_network_stub.create!(:external_facing => true, :ems_id => ems_cloud.id) }

  let!(:ems_infra)           { cloud_manager_stub.create!(:type => "ManageIQ::Providers::Openstack::InfraManager") }
  let!(:infra_cloud_network) { cloud_network_stub.create!(:external_facing => false, :ems_id => ems_infra.id) }

  migration_context :up do
    it "sets correct type to cloud_network objects according to cloud_manager" do
      migrate

      expect(empty_cloud_network.reload.type).to eq(described_class::CLOUD_TEMPLATE_CLASS)
      expect(cloud_cloud_network.reload.type).to eq(described_class::CLOUD_PUBLIC_CLASS)
      expect(infra_cloud_network.reload.type).to eq(described_class::CLOUD_PRIVATE_CLASS)
    end
  end

  migration_context :down do
    it "sets type = nil for all cloud_networks" do
      cloud_cloud_network.type = described_class::CLOUD_PUBLIC_CLASS
      cloud_cloud_network.save!

      infra_cloud_network.type = described_class::CLOUD_PRIVATE_CLASS
      infra_cloud_network.save!

      migrate

      expect(cloud_cloud_network.reload.type).to be_nil
      expect(infra_cloud_network.reload.type).to be_nil
    end
  end
end
