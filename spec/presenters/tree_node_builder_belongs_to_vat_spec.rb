describe TreeNodeBuilderBelongsToVat do
  describe '#ext_management_system_node' do
    it 'returns node correctly' do
      ems = FactoryGirl.create(:ems_azure_network)
      node = TreeNodeBuilderBelongsToVat.build(ems, nil, {})
      expect(node[:hideCheckbox]).to eq(true)
    end
  end

  describe '#ems_folder_node' do
    it 'returns node correctly' do
      folder = FactoryGirl.create(:ems_folder)
      datacenter = FactoryGirl.create(:datacenter)
      node_folder = TreeNodeBuilderBelongsToVat.build(folder, nil, :selected => ["EmsFolder_#{folder[:id]}"])
      node_datacenter = TreeNodeBuilderBelongsToVat.build(datacenter, nil, {})
      expect(node_folder[:select]).to eq(true)
      expect(node_datacenter[:hideCheckbox]).to eq(true)
    end
  end

  describe '#normal_folder_node' do
    it 'returns node correctly' do
      folder = FactoryGirl.create(:ems_folder)
      node_folder = TreeNodeBuilderBelongsToVat.build(folder, nil, :selected => [])
      expect(node_folder[:title]).to eq(folder.name)
      expect(node_folder[:tooltip]).to eq("Folder: #{folder.name}")
      expect(node_folder[:select]).to eq(false)
    end
  end

  describe '#cluster_node' do
    it 'returns node correctly' do
      cluster = FactoryGirl.create(:ems_cluster)
      node = TreeNodeBuilderBelongsToVat.build(cluster, nil, {})
      expect(node[:hideCheckbox]).to eq(true)
    end
  end

  it '#generic_node' do
    ems = FactoryGirl.create(:ems_azure_network)
    node = TreeNodeBuilderBelongsToVat.build(ems, nil, :checkable => true)
    expect(node[:cfmeNoClick]).to eq(true)
    expect(node[:checkable]).to eq(true)
  end
end
