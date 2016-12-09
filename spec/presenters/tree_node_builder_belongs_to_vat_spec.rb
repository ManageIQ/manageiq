describe TreeNodeBuilderBelongsToVat do
  describe '#ext_management_system_node' do
    let(:ems) { FactoryGirl.create(:ems_azure_network) }
    it 'returns node correctly' do
      node = TreeNodeBuilderBelongsToVat.build(ems, nil, {})
      expect(node[:hideCheckbox]).to be true
    end
  end

  describe '#ems_folder_node' do
    let(:folder) { FactoryGirl.create(:ems_folder) }
    let(:datacenter) { FactoryGirl.create(:datacenter) }
    it 'returns datacenter node without checkbox' do
      node_datacenter = TreeNodeBuilderBelongsToVat.build(datacenter, nil, {})
      expect(node_datacenter[:hideCheckbox]).to be true
    end
    it 'returns folder selected node correctly' do
      node_folder = TreeNodeBuilderBelongsToVat.build(folder, nil, :selected => ["EmsFolder_#{folder[:id]}"])
      expect(node_folder[:select]).to be true
    end
    it 'returns folder unselected node correctly' do
      node_folder = TreeNodeBuilderBelongsToVat.build(folder, nil, :selected => [])
      expect(node_folder[:select]).to be false
    end
  end

  describe '#normal_folder_node' do
    let(:folder) { FactoryGirl.create(:ems_folder) }
    it 'returns node correctly' do
      node_folder = TreeNodeBuilderBelongsToVat.build(folder, nil, :selected => [])
      expect(node_folder[:title]).to eq(folder.name)
      expect(node_folder[:tooltip]).to eq("Folder: #{folder.name}")
      expect(node_folder[:select]).to be false
    end
  end

  describe '#cluster_node' do
    let(:cluster) { FactoryGirl.create(:ems_cluster) }
    it 'returns cluster node without checkbox' do
      node = TreeNodeBuilderBelongsToVat.build(cluster, nil, {})
      expect(node[:hideCheckbox]).to be_truthy
    end
  end

  describe '#generic_node' do
    let(:ems) { FactoryGirl.create(:ems_azure_network) }
    it 'sets node correctly' do
      node = TreeNodeBuilderBelongsToVat.build(ems, nil, :checkable_checkboxes => true)
      expect(node[:cfmeNoClick]).to be_truthy
      expect(node[:checkable]).to be_truthy
    end
  end
end
