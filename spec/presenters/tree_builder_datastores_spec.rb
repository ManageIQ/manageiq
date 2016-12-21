describe TreeBuilderDatastores do
  context 'TreeBuilderDatastores' do
    before do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Datastores Group")
      login_as FactoryGirl.create(:user, :userid => 'datastores_wilma', :miq_groups => [@group])
      @host = FactoryGirl.create(:host, :name => 'Host Name')
      FactoryGirl.create(:storage, :name => 'Name', :id => 1, :hosts => [@host])
      @datastore = [{:id => 1, :name => 'Datastore', :location => 'Location', :capture => false}]
      @datastores_tree = TreeBuilderDatastores.new(:datastore, :datastore_tree, {}, true, @datastore)
    end
    it 'sets tree to have full ids, not lazy and no root' do
      root_options = @datastores_tree.send(:tree_init_options, nil)
      expect(root_options).to eq(:full_ids => false, :add_root => false, :lazy => false)
    end
    it 'sets locals correctly' do
      locals = @datastores_tree.send(:set_locals_for_render)
      expect(locals[:checkboxes]).to eq(true)
      expect(locals[:onselect]).to eq("miqOnCheckCUFilters")
      expect(locals[:check_url]).to eq("/ops/cu_collection_field_changed/")
    end
    it 'sets Datastore node correctly' do
      parent = @datastores_tree.send(:x_get_tree_roots, false, nil)
      expect(parent.first[:text]).to eq("<b>Datastore</b> [#{@datastore.first[:location]}]")
      expect(parent.first[:tip]).to eq("Datastore [#{@datastore.first[:location]}]")
      expect(parent.first[:image]).to eq('100/storage.png')
    end
    it 'sets Host node correctly' do
      parent = @datastores_tree.send(:x_get_tree_roots, false, nil)
      kids = @datastores_tree.send(:x_get_tree_hash_kids, parent.first, false)
      expect(kids.first[:text]).to eq(@host[:name])
      expect(kids.first[:tip]).to eq(@host[:name])
      expect(kids.first[:image]).to eq('100/host.png')
      expect(kids.first[:hideCheckbox]).to eq(true)
      expect(kids.first[:cfmeNoClick]).to eq(true)
      expect(kids.first[:children]).to eq([])
    end
  end
end
