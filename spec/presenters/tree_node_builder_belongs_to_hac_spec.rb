describe TreeNodeBuilderBelongsToHac do
  it '#ext_management_system_node' do
    ems = FactoryGirl.create(:ems_azure_network)
    node = TreeNodeBuilderBelongsToHac.build(ems, nil, {:selected => ["#{ems.class.name}_#{ems[:id]}"]})
    node_unselected =  TreeNodeBuilderBelongsToHac.build(ems, nil, {:selected => []})
    expect(node[:select]).to eq(true)
    expect(node_unselected[:select]).to eq(false)
  end

  it '#host_node' do
    host = FactoryGirl.create(:host)
    node = TreeNodeBuilderBelongsToHac.build(host, nil, {})
    expect(node[:hideCheckbox]).to eq(true)
  end

  it '#cluster_node' do
    cluster = FactoryGirl.create(:ems_cluster)
    node = TreeNodeBuilderBelongsToHac.build(cluster, nil, {:selected => ["EmsCluster_#{cluster[:id]}"]})
    node_unselected = TreeNodeBuilderBelongsToHac.build(cluster, nil, {:selected => []})
    # binding.pry
    #expect(node[:select]).to eq(true)
    #expect(node_unselected[:select]).to eq(false)
  end

  it '#ems_folder_node' do
    dc = FactoryGirl.create(:datacenter)
    folder = FactoryGirl.create(:datacenter)
    dc_node = TreeNodeBuilderBelongsToHac.build(dc, nil, {:selected => ["Datacenter_#{dc[:id]}"]})
    dc_node_unselected = TreeNodeBuilderBelongsToHac.build(dc, nil, {:selected => []})
    folder_node = TreeNodeBuilderBelongsToHac.build(folder, nil, {:selected => ["EmsFolder_#{folder[:id]}"]})
    folder_node_unselected = TreeNodeBuilderBelongsToHac.build(folder, nil, {:selected => []})
    # binding.pry
    #expect(dc_node[:select]).to eq(true)
    #expect(dc_node_unselected[:select]).to eq(false)
    #expect(folder_node[:select]).to eq(true)
    #expect(folder_node_unselected[:select]).to eq(false)
  end

  it '#resource_pool_node' do
    rp = FactoryGirl.create(:resource_pool)
    node = TreeNodeBuilderBelongsToHac.build(rp, nil, {:selected => ["ResourcePool_#{rp[:id]}"]})
    node_unselected = TreeNodeBuilderBelongsToHac.build(rp, nil, {:selected => []})
    # binding.pry
    #expect(node[:select]).to eq(true)
    #expect(node_unselected[:select]).to eq(false)
  end
end
