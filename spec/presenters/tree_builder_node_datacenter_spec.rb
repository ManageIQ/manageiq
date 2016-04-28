describe TreeNodeBuilder do
  context '#tooltip' do
    it 'returns correct tooltip for ResourcePool node' do
      object = FactoryGirl.build(:resource_pool)
      node = TreeNodeBuilderDatacenter.build(object, nil, {})
      expect(node[:tooltip]).to eq("Resource Pool: #{node[:title]} (Click to view)")
    end
    it 'returns correct tooltip for Host node' do
      object = FactoryGirl.build(:host)
      node = TreeNodeBuilderDatacenter.build(object, nil, {})
      expect(node[:tooltip]).to eq("Host / Node: #{node[:title]} (Click to view)")
    end
    it 'returns correct tooltip for VM node' do
      object = FactoryGirl.build(:vm)
      node = TreeNodeBuilderDatacenter.build(object, nil, {})
      expect(node[:tooltip]).to eq("VM: #{node[:title]} (Click to view)")
    end
    it 'returns correct tooltip for Cluster node' do
      object = FactoryGirl.build(:ems_cluster)
      node = TreeNodeBuilderDatacenter.build(object, nil, {})
      expect(node[:tooltip]).to eq("Cluster / Deployment Role: #{node[:title]} (Click to view)")
    end
    it 'returns correct tooltip for Datacenter node' do
      object = FactoryGirl.build(:datacenter)
      node = TreeNodeBuilderDatacenter.build(object, nil, {})
      expect(node[:tooltip]).to eq("Datacenter: #{node[:title]} (Click to view)")
    end
    it 'returns correct tooltip for Folder node' do
      object = FactoryGirl.build(:ems_folder)
      node = TreeNodeBuilderDatacenter.build(object, nil, {})
      expect(node[:tooltip]).to eq("Folder: #{node[:title]} (Click to view)")
    end
  end
  context 'icon' do
    it 'is blue folder when type is :vat' do
      object = FactoryGirl.build(:ems_folder)
      node = TreeNodeBuilderDatacenter.build(object, nil, :type => :vat)
      expect(node[:icon]).to eq(ActionController::Base.helpers.image_path("100/#{"blue_folder.png"}"))
    end
    it 'is normal folder when type is not :vat' do
      object = FactoryGirl.build(:ems_folder)
      node = TreeNodeBuilderDatacenter.build(object, nil, {})
      expect(node[:icon]).to eq(ActionController::Base.helpers.image_path("100/#{"folder.png"}"))
    end
  end
end
