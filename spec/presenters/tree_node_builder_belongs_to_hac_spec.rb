describe TreeNodeBuilderBelongsToHac do
  describe '#ext_management_system_node' do
    let(:ems) { FactoryGirl.create(:ems_azure_network) }
    it 'returns selected node' do
      node = TreeNodeBuilderBelongsToHac.build(ems, nil, :selected => ["#{ems.class.name}_#{ems[:id]}"])
      expect(node[:select]).to be true
    end
    it 'returns unselected node' do
      node_unselected = TreeNodeBuilderBelongsToHac.build(ems, nil, :selected => [])
      expect(node_unselected[:select]).to be false
    end

  end

  describe '#host_node' do
    it 'returns node without checkbox' do
      node = TreeNodeBuilderBelongsToHac.build(FactoryGirl.create(:host), nil, {})
      expect(node[:hideCheckbox]).to be true
    end
  end

  describe '#cluster_node' do
    let(:cluster) { FactoryGirl.create(:ems_cluster) }
    it 'returns selected node' do
      node = TreeNodeBuilderBelongsToHac.build(cluster,
                                               nil,
                                               :selected             => ["EmsCluster_#{cluster[:id]}"],
                                               :checkable_checkboxes => true)
      expect(node[:select]).to be true
      expect(node[:checkable]).to be true
    end
    it 'returns unselected node' do
      node_unselected = TreeNodeBuilderBelongsToHac.build(cluster, nil, :selected => [])
      expect(node_unselected[:select]).to be false
    end
  end

  describe '#ems_folder_node' do
    let(:dc) { FactoryGirl.create(:datacenter) }
    let(:folder) { FactoryGirl.create(:ems_folder) }
    it 'returns selected datastore node' do
      dc_node = TreeNodeBuilderBelongsToHac.build(dc,
                                                  nil,
                                                  :selected             => ["Datacenter_#{dc[:id]}"],
                                                  :checkable_checkboxes => true)
      expect(dc_node[:select]).to be true
      expect(dc_node[:checkable]).to be true
    end
    it 'returns unselected datastore node' do
      dc_node_unselected = TreeNodeBuilderBelongsToHac.build(dc, nil, :selected => [])
      expect(dc_node_unselected[:select]).to be false
    end
    it 'returns selected folder node' do
      folder_node = TreeNodeBuilderBelongsToHac.build(folder, nil, :selected => ["EmsFolder_#{folder[:id]}"])
      expect(folder_node[:select]).to be true
    end
    it 'returns selected folder node' do
      folder_node_unselected = TreeNodeBuilderBelongsToHac.build(folder, nil, :selected => [])
      expect(folder_node_unselected[:select]).to be false
    end

  end

  describe '#resource_pool_node' do
    let(:rp) { FactoryGirl.create(:resource_pool) }
    it 'returns selected node' do
      node = TreeNodeBuilderBelongsToHac.build(rp, nil, :selected => ["ResourcePool_#{rp[:id]}"])
      expect(node[:select]).to be true
    end
    it 'returns unselected node' do
      node_unselected = TreeNodeBuilderBelongsToHac.build(rp, nil, :selected => [])
      expect(node_unselected[:select]).to be false
    end
  end
end
