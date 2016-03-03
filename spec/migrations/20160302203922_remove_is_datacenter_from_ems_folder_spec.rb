require_migration

describe RemoveIsDatacenterFromEmsFolder do
  let(:ems_folder_stub) { migration_stub(:EmsFolder) }

  migration_context :up do
    it "sets the type column" do
      folder = ems_folder_stub.create!(:name => "Datacenters", :is_datacenter => false)
      dc     = ems_folder_stub.create!(:name => "Prod-DC", :is_datacenter => true)

      migrate

      expect(folder.reload).to have_attributes(:type => nil)
      expect(dc.reload).to     have_attributes(:type => 'Datacenter')
    end
  end

  migration_context :down do
    it "adds the is_datacenter column" do
      dc              = ems_folder_stub.create!(:name => "Prod-DC", :type => "Datacenter")
      folder          = ems_folder_stub.create!(:name => "Datacenters", :type => nil)
      storage_cluster = ems_folder_stub.create!(:name => "Storage Cluster", :type => "StorageCluster")

      migrate

      expect(storage_cluster.reload).to have_attributes(:is_datacenter => false)
      expect(folder.reload).to          have_attributes(:is_datacenter => false)
      expect(dc.reload).to              have_attributes(:is_datacenter => true)
    end
  end
end
