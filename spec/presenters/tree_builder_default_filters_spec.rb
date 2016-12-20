describe TreeBuilderDefaultFilters do
  context 'TreeBuilderDefaultFilters' do
    before do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Default filters Group")
      login_as FactoryGirl.create(:user, :userid => 'default_filters__wilma', :miq_groups => [@group])
      @filters = [FactoryGirl.create(:miq_search,
                                     :name        => "default_Platform / HyperV",
                                     :description => "Platform / HyperV",
                                     :options     => nil,
                                     :db          => "Host",
                                     :search_type => "default",
                                     :search_key  => nil)]
      @filters.push(FactoryGirl.create(:miq_search,
                                       :name        => "default_Environment / UAT",
                                       :description => "Environment / UAT",
                                       :options     => nil,
                                       :db          => "MiqTemplate",
                                       :search_type => "default",
                                       :search_key  => "_hidden_"))
      @filters.push(FactoryGirl.create(:miq_search,
                                       :name        => "default_Environment / Prod",
                                       :description => "Environment / Prod",
                                       :options     => nil,
                                       :db          => "MiqTemplate",
                                       :search_type => "default",
                                       :search_key  => "_hidden_"))
      @filters.push(FactoryGirl.create(:miq_search,
                                       :name        => "default_Environment / Prod",
                                       :description => "Environment / Prod",
                                       :options     => nil,
                                       :db          => "Container",
                                       :search_type => "default",
                                       :search_key  => "_hidden_"))
      @filters.push(FactoryGirl.create(:miq_search,
                                       :name        => "default_Environment / Prod",
                                       :description => "Environment / Prod",
                                       :options     => nil,
                                       :db          => "ContainerGroup",
                                       :search_type => "default",
                                       :search_key  => "_hidden_"))
      @filters.push(FactoryGirl.create(:miq_search,
                                       :name        => "default_Environment / Prod",
                                       :description => "Environment / Prod",
                                       :options     => nil,
                                       :db          => "ContainerService",
                                       :search_type => "default",
                                       :search_key  => "_hidden_"))
      @filters.push(FactoryGirl.create(:miq_search,
                                       :name        => "default_Environment / Prod",
                                       :description => "Environment / Prod",
                                       :options     => nil,
                                       :db          => "Storage",
                                       :search_type => "default",
                                       :search_key  => "_hidden_"))
      @filters.push(FactoryGirl.create(:miq_search,
                                       :name        => "default_Environment / Prod",
                                       :description => "Environment / Prod",
                                       :options     => nil,
                                       :db          => "Vm",
                                       :search_type => "default",
                                       :search_key  => "_hidden_"))
      @sb = {:active_tree => :default_filters_tree}
      @default_filters_tree = TreeBuilderDefaultFilters.new(:df_tree, :df, @sb, true, @filters)
    end

    it 'is not lazy' do
      tree_options = @default_filters_tree.send(:tree_init_options, :df)
      expect(tree_options[:lazy]).to eq(false)
    end

    it 'has no root' do
      tree_options = @default_filters_tree.send(:tree_init_options, :df)
      root = @default_filters_tree.send(:root_options)
      expect(tree_options[:add_root]).to eq(false)
      expect(root).to eq([])
    end

    it 'returns folders as root kids' do
      kids = @default_filters_tree.send(:x_get_tree_roots, false)
      kids.each do |kid|
        expect(kid[:image]).to eq('100/folder.png')
        expect(kid[:hideCheckbox]).to eq(true)
        expect(kid[:cfmeNoClick]).to eq(true)
      end
    end

    it 'returns filter or folder as folder kids' do
      data = @default_filters_tree.send(:prepare_data, @filters)
      grandparents = @default_filters_tree.send(:x_get_tree_roots, false)
      grandparents.each do |grandparent|
        parents = @default_filters_tree.send(:x_get_tree_hash_kids, grandparent, false)
        parents.each do |parent|
          path = parent[:id].split('_')
          offsprings = data.fetch_path(path)
          if offsprings.kind_of?(Hash)
            kids = @default_filters_tree.send(:x_get_tree_hash_kids, parent, false)
            kids.each do |kid|
              expect(kid[:image]).to eq('100/folder.png')
              expect(kid[:hideCheckbox]).to eq(true)
              expect(kid[:cfmeNoClick]).to eq(true)
              grandkids = @default_filters_tree.send(:x_get_tree_hash_kids, kid, false)
              grandkids.each_with_index do |grandkid, index|
                expect(grandkid[:image]).to eq('100/filter.png')
                expect(grandkid[:select]).to eq(offsprings[kid[:text]][index][:search_key] != "_hidden_")
              end
            end
          else
            kids = @default_filters_tree.send(:x_get_tree_hash_kids, parent, false)
            kids.each_with_index do |kid, index|
              expect(kid[:image]).to eq('100/filter.png')
              expect(kid[:select]).to eq(offsprings[index][:search_key] != "_hidden_")
            end
          end
        end
      end
    end
  end
end
