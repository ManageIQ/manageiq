describe TreeBuilderVat do
  context 'TreeBuilderVat' do
    before(:each) do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Vat Group")
      login_as FactoryGirl.create(:user, :userid => 'datacenter_wilma', :miq_groups => [@group])
      cluster = FactoryGirl.create(:ems_cluster)
      class << cluster
        def children
          [OpenStruct.new(:datacenters_only => [FactoryGirl.create(:datacenter)],
                          :folders_only     => [FactoryGirl.create(:ems_folder)],
                          :name             => 'Datacenters',)]
        end

        def image_name
          'cluster'
        end
      end
      @vat_tree = TreeBuilderVat.new(:vat_tree, :vat, {}, true, cluster, true)
    end

    it 'returns EmsCluster as root' do
      root = @vat_tree.send(:root_options)
      image = "100/vendor-#{@vat_tree.instance_variable_get(:@root).image_name}.png"
      expect(root[0]).to eq(@vat_tree.instance_variable_get(:@root).name)
      expect(root[1]).to eq(@vat_tree.instance_variable_get(:@root).name)
      expect(root[2]).to eq(image)
    end

    it 'returns children correctly' do
      kids = @vat_tree.send(:x_get_tree_roots, false)
      expect(kids[0]).to be_a_kind_of(EmsFolder)
      expect(kids[1]).to be_a_kind_of(Datacenter)
    end
  end
end
