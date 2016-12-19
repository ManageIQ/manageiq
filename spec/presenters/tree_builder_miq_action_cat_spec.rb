describe TreeBuilderMiqActionCat do
  before do
    role = MiqUserRole.find_by_name("EvmRole-operator")
    @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Tags Group")
    login_as FactoryGirl.create(:user, :userid => 'tags_wilma', :miq_groups => [@group])
    @tag1 = FactoryGirl.create(:classification, :name => 'tag1', :show => false)
    @folder1 = FactoryGirl.create(:classification, :name => 'folder1', :show => true)
    @folder1.entries.push(@tag1)
    @tag2 = FactoryGirl.create(:classification, :name => 'tag2', :show => false)
    @folder2 = FactoryGirl.create(:classification, :name => 'folder2', :show => true)
    @folder2.entries.push(@tag2)
    @group = FactoryGirl.create(:miq_group)
    @tenant = "TestTenant"
    @tenant = "#{@tenant} Tags"
  end
  context 'read-only mode' do
    before do
      @tree_name = 'action_tags'
      @tree = TreeBuilderMiqActionCat.new('action_tags_tree', 'action_tags', {}, true, @tenant)
    end
    it 'set init options correctly' do
      tree_options = @tree.send(:tree_init_options, @tree_name)
      expect(tree_options).to eq(:expand => true, :lazy => false)
    end
    it 'set locals for render correctly' do
      locals = @tree.send(:set_locals_for_render)
      expect(locals[:id_prefix]).to eq('cat_tree')
      expect(locals[:click_url]).to eq("/miq_policy/action_tag_pressed/")
      expect(locals[:onclick]).to eq("miqOnClickTagCat")
    end
    it 'set node' do
      desc1 = _("Category: %{description}") % {:description => @tag1.description}
      desc2 = @tag1.description
      node = @tree.send(:override, {}, @tag1, nil, nil)

      expect(node[:hideCheckbox]).to eq(true)
      expect(node[:tooltip]).to eq(desc1)
      expect(node[:title]).to eq(desc2)
      expect(node[:cfmeNoClick]).to eq(false)

      desc1 = _("Category: %{description}") % {:description => @folder1.description}
      desc2 = @folder1.description
      node = @tree.send(:override, {}, @folder1, nil, nil)

      expect(node[:hideCheckbox]).to eq(true)
      expect(node[:tooltip]).to eq(desc1)
      expect(node[:title]).to eq(desc2)
    end

    it 'sets root' do
      roots = @tree.send(:root_options)
      expect(roots).to eq([@tenant, @tenant, "100/tag.png"])
    end
    it 'sets first level nodes correctly' do
      roots = @tree.send(:x_get_tree_roots, false, nil)
      expect(roots).to eq([@folder1, @folder2].sort_by { |c| c.description.downcase })
    end
    it 'sets second level nodes correctly' do
      kid1 = @tree.send(:x_get_tree_classification_kids, @folder1, false)
      kid2 = @tree.send(:x_get_tree_classification_kids, @folder2, false)

      expect(kid1[0].id).to eq(@tag1.id)
      expect(kid1[0].description).to eq(@tag1.description)
      expect(kid1[0].parent_id).to eq(@folder1.id)

      expect(kid2[0].id).to eq(@tag2.id)
      expect(kid2[0].description).to eq(@tag2.description)
      expect(kid2[0].parent_id).to eq(@folder2.id)
    end
  end
end
