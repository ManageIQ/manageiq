describe TreeBuilderBelongsToVat do
  before do
    login_as FactoryGirl.create(:user_with_group, :role => "operator", :settings => {})
    @edit = nil
    @group = FactoryGirl.create(:miq_group)
    @ems_folder = FactoryGirl.create(:ems_folder)
    @subfolder = FactoryGirl.create(:ems_folder, :name => 'vm')
    @folder = FactoryGirl.create(:ems_folder)
    @subfolder.with_relationship_type("ems_metadata") { @subfolder.add_child(@ems_folder) }
    @ems_azure_network = FactoryGirl.create(:ems_azure_network)
    @ems_azure_network.with_relationship_type("ems_metadata") { @ems_azure_network.add_child(@folder) }
    @datacenter = FactoryGirl.create(:datacenter)
    @datacenter.with_relationship_type("ems_metadata") { @datacenter.add_folder(@subfolder) }
    FactoryGirl.create(:ems_redhat)
    FactoryGirl.create(:ems_google_network)
    @vat_tree = TreeBuilderBelongsToVat.new(:vat,
                                            :vat_tree,
                                            {:trees => {}},
                                            true,
                                            :edit     => @edit,
                                            :filters  => {},
                                            :group    => @group,
                                            :selected => {})
  end

  it 'set init options correctly' do
    tree_options = @vat_tree.send(:tree_init_options, :vat)
    expect(tree_options).to eq(:full_ids  => true,
                               :add_root  => false,
                               :lazy      => false,
                               :checkable => @edit.present?,
                               :selected  => {})
  end

  it 'set locals for render correctly' do
    locals = @vat_tree.send(:set_locals_for_render)
    expect(locals[:id_prefix]).to eq('vat_')
    expect(locals[:checkboxes]).to eq(true)
    expect(locals[:check_url]).to eq("/ops/rbac_group_field_changed/#{@group.id || "new"}___")
    expect(locals[:onclick]).to eq(false)
    expect(locals[:oncheck]).to eq(@edit ? "miqOnCheckUserFilters" : nil,)
    expect(locals[:highlight_changes]).to eq(true)
  end

  it '#x_get_tree_datacenter_kids' do
    kids = @vat_tree.send(:x_get_tree_datacenter_kids, @datacenter, false)
    expect(kids).to include(@ems_folder)
    expect(kids.size).to eq(1)
  end
end
