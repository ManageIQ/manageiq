describe TreeBuilderDatacenter do
  context 'TreeBuilderDatacenter Cluster root' do
    before(:each) do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Datacenter Group Cluster root")
      login_as FactoryGirl.create(:user, :userid => 'datacenter_wilma', :miq_groups => [@group])
      host = FactoryGirl.create(:host)

      vm = FactoryGirl.create(:vm)
      cluster = FactoryGirl.create(:ems_cluster, :hosts => [host], :vms => [vm])
      class << cluster
        def resource_pools
          [FactoryGirl.create(:resource_pool)]
        end
      end
      @datacenter_tree = TreeBuilderDatacenter.new(:datacenter_tree, :datacenter, {}, true, cluster)
    end

    it 'returns EmsCluster as root' do
      root = @datacenter_tree.send(:root_options)
      expect(root[0]).to eq(@datacenter_tree.instance_variable_get(:@root).name)
      expect(root[1]).to eq("Cluster: #{@datacenter_tree.instance_variable_get(:@root).name}")
      expect(root[2]).to eq("100/cluster.png")
    end

    it 'returns right kind of children' do
      kids = @datacenter_tree.send(:x_get_tree_roots, false)
      expect(kids[0]).to be_a_kind_of(Host)
      expect(kids[1]).to be_a_kind_of(ResourcePool)
      expect(kids[2]).to be_a_kind_of(Vm)
    end
  end

  context 'TreeBuilderDatacenter Resource pool root' do
    before(:each) do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group,
                                  :miq_user_role => role,
                                  :description   => "Datacenter Group Resource pool root")
      login_as FactoryGirl.create(:user, :userid => 'datacenter_wilma', :miq_groups => [@group])
      cluster = FactoryGirl.create(:resource_pool)
      class << cluster
        def resource_pools
          [FactoryGirl.create(:resource_pool)]
        end
        def vms
          [FactoryGirl.create(:vm)]
        end
      end
      @datacenter_tree = TreeBuilderDatacenter.new(:datacenter_tree, :datacenter, {}, true, cluster)
    end

    it 'returns ResourcePool as root' do
        root = @datacenter_tree.send(:root_options)
        expect(root[0]).to eq(@datacenter_tree.instance_variable_get(:@root).name)
        expect(root[1]).to eq("Resource Pool: #{@datacenter_tree.instance_variable_get(:@root).name}")
        expect(root[2]).to eq(@datacenter_tree.instance_variable_get(:@root).vapp ? '100/vapp.png' : '100/resource_pool.png')
    end

    it 'returns right kind of children' do
      kids = @datacenter_tree.send(:x_get_tree_roots, false)
      expect(kids[0]).to be_a_kind_of(ResourcePool)
      expect(kids[1]).to be_a_kind_of(Vm)
    end
  end
end
