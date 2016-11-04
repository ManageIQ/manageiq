describe TreeBuilderBelongsToHac do
  before do
    login_as FactoryGirl.create(:user_with_group, :role => "operator", :settings => {})
    @edit = nil
    @group = FactoryGirl.create(:miq_group)
    @datacenter1 = FactoryGirl.create(:datacenter)
    @datacenter2 = FactoryGirl.create(:datacenter)
    @cluster = FactoryGirl.create(:ems_cluster)
    @rp1 = FactoryGirl.create(:resource_pool, :is_default => true)
    @rp2 = FactoryGirl.create(:resource_pool)
    @ems_folder = FactoryGirl.create(:ems_folder)
    @subfolder = FactoryGirl.create(:ems_folder, :name => 'host')
    @subfolder_vm = FactoryGirl.create(:ems_folder, :name => 'vm')
    @folder = FactoryGirl.create(:ems_folder)
    @host = FactoryGirl.create(:host, :ems_cluster => @cluster)
    @cluster.add_resource_pool(@rp1)
    @rp1.with_relationship_type("ems_metadata") { @rp1.add_child(@rp2) }

    @folder.with_relationship_type("ems_metadata") { @folder.add_child(@subfolder) }
    @folder.with_relationship_type("ems_metadata") { @folder.add_child(@datacenter1) }
    @subfolder.with_relationship_type("ems_metadata") { @subfolder.add_child(@datacenter2) }
    @subfolder.with_relationship_type("ems_metadata") { @subfolder.add_child(@ems_folder) }
    @subfolder_vm.with_relationship_type("ems_metadata") { @subfolder_vm.add_child(@ems_folder) }
    @subfolder.with_relationship_type("ems_metadata") { @subfolder.add_host(@host) }
    @subfolder.with_relationship_type("ems_metadata") { @subfolder.add_cluster(@cluster) }

    @datacenter1.with_relationship_type("ems_metadata") { @datacenter1.add_folder(@subfolder) }
    @ems_azure_network = FactoryGirl.create(:ems_azure_network)
    @ems_azure_network.with_relationship_type("ems_metadata") { @ems_azure_network.add_child(@folder) }
    FactoryGirl.create(:ems_redhat)
    FactoryGirl.create(:ems_google_network)
    @hac_tree = TreeBuilderBelongsToHac.new(:hac, :hac_tree, {:trees => {}}, true, :edit => @edit, :filters => {}, :group => @group, :selected => {})
  end

  it 'set init options correctly' do
    tree_options = @hac_tree.send(:tree_init_options, :hac)
    expect(tree_options).to eq(:full_ids => true, :add_root => false, :lazy => false, :checkable => @edit.present?, :selected => {})
  end

  it 'set locals for render correctly' do
    locals = @hac_tree.send(:set_locals_for_render)
    expect(locals[:id_prefix]).to eq('hac_')
    expect(locals[:checkboxes]).to eq(true)
    expect(locals[:check_url]).to eq("/ops/rbac_group_field_changed/#{@group.id || "new"}___")
    expect(locals[:onclick]).to eq(false)
    expect(locals[:oncheck]).to eq(@edit ? "miqOnCheckUserFilters" : nil,)
    expect(locals[:highlight_changes]).to eq(true)
  end

  it 'sets root to empty one' do
    root = @hac_tree.send(:root_options)
    expect(root).to eq([])
  end

  it '#x_get_tree_roots' do
    roots = @hac_tree.send(:x_get_tree_roots, false , nil)
    expect(roots).to eq(ExtManagementSystem.all)
  end

  it '#x_get_tree_provider_kids' do
    kids = @hac_tree.send(:x_get_kids_provider, @ems_azure_network, false)
    expect(kids).to include(@datacenter1)
    expect(kids).to include(@subfolder)
    expect(kids.size).to eq(2)
  end

  it '#x_get_tree_folder_kids' do
    kids = @hac_tree.send(:x_get_tree_folder_kids, @subfolder, false)
    expect(kids).to include(@datacenter2)
    expect(kids).to include(@ems_folder)
    expect(kids).to include(@cluster)
    expect(kids).to include(@host)
    expect(kids.size).to eq(4)
  end

  it '#x_get_tree_datacenter_kids' do
    kids = @hac_tree.send(:x_get_tree_datacenter_kids, @datacenter1, false)
    expect(kids).to include(@host)
    expect(kids).to include(@cluster)
    expect(kids).to include(@ems_folder)
    expect(kids.size).to eq(3)
  end

  it '#x_get_tree_cluster_kids TODO add Resource Pool' do
    kids = @hac_tree.send(:x_get_tree_cluster_kids, @cluster, false)
    expect(kids).to include(@host)
    binding.pry
    expect(kids.size).to eq(1)
  end

  it '#x_get_resource_pool_kids' do
    kids = @hac_tree.send(:x_get_resource_pool_kids, @rp1, false)
    no_kids = @hac_tree.send(:x_get_resource_pool_kids, @rp2, false)
    expect(kids).to include(@rp2)
    expect(kids.size).to eq(1)
    expect(no_kids).to eq([])
  end
end