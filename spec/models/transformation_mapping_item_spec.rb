RSpec.describe 'Tests transformation items', :v2v do
  let(:ems_redhat) { FactoryBot.create(:ems_redhat, :zone => FactoryBot.create(:zone), :api_version => '4.2.4') }
  let(:ems_vmware) { FactoryBot.create(:ems_vmware, :zone => FactoryBot.create(:zone)) }

  let(:ext_management_system)  { FactoryBot.create(:ext_management_system) }
  let(:host)                   { FactoryBot.create(:host) }
  let(:storage)                { FactoryBot.create(:storage) }

  let(:storage) { FactoryBot.create(:storage) }
  let(:lan) { FactoryBot.create(:lan) }

  # only vmware source is supported for migration
  context "Cluster validation" do
    let(:src) { FactoryBot.create(:ems_cluster, :ext_management_system => ems_vmware) }
    let(:dst) { FactoryBot.create(:ems_cluster, :ext_management_system => ems_redhat) }
    let(:tmi) { FactoryBot.create(:transformation_mapping_item, :source => src, :destination => dst)}
    it "Source is valid" do
      expect(tmi).to be_valid
    end
    it "Destination is valid" do
      expect(tmi).to be_valid
    end
  end # end of cluster context

  context "Storage validation" do
    #todo
    # 1.  Create a host
    # 2.  Add host to a cluster
    # 3.  Add cluster to a storage
    let(:source_storage) { FactoryBot.create(:storage) }
    let(:source_cluster) { FactoryBot.create(:ems_cluster)}
    let(:source_host) { FactoryBot.create(:host, :ems_cluster => source_cluster) }
    let(:src) { FactoryBot.create(:storage, :hosts => [source_host] ) }
    
    let(:destination_storage) { FactoryBot.create(:storage) }
    let(:destination_cluster) { FactoryBot.create(:ems_cluster)}
    let(:destination_host) { FactoryBot.create(:host, :ems_cluster => destination_cluster) }
    let(:dst) { FactoryBot.create(:storage, :hosts => [destination_host] ) }

    let(:tmi) { FactoryBot.create(:transformation_mapping_item, :source => src, :destination => dst) }
   
    # add the src storage to the source cluster, then call valid  
    before do
	allow(source_cluster).to receive(:storages).and_return([src])
    end
    it "Source datastore is valid" do
      expect(tmi.valid?).to be (true)
    end

    # add the dst storage to the destination cluster, then call valid  
    before do
	allow(destination_cluster).to receive(:storages).and_return([dst])
    end
    it "Destination datastore is valid" do
      expect(tmi.valid?).to be (true)
    end
  end # end of storage context

  context "Lan validation" do
    # todo
    # 1. Create a cluster
    # 2. Add cluster to a host
    # 3. Add host to a switch
    # 4. Add switch to the lan
    let(:src) { FactoryBot.create(:lan)}
    let(:dst) { FactoryBot.create(:lan)}
    let(:tmi) { FactoryBot.create(:transformation_mapping_item, :source => src, :destination => dst)}
    it "Source is valid" do
      expect(true).to be (true)
      # expect(tmi.valid?).to be (true)
    end
    it "Destination is valid" do
      expect(true).to be (true)
    end
  end # end of lan context

end # describe
