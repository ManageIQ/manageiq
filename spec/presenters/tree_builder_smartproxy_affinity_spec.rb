describe TreeBuilderSmartproxyAffinity do
  context 'TreeBuilderSmartproxyAffinity' do
    before do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "SmartProxy Affinity Group")
      login_as FactoryGirl.create(:user, :userid => 'smartproxy_affinity_wilma', :miq_groups => [@group])

      @selected_zone = FactoryGirl.create(:zone, :name => 'zone1')

      @storage1 = FactoryGirl.create(:storage)
      @storage2 = FactoryGirl.create(:storage)

      @host1 = FactoryGirl.create(:host, :name => 'host1', :storages => [@storage1])
      @host2 = FactoryGirl.create(:host, :name => 'host2', :storages => [@storage2])

      @ems = FactoryGirl.create(:ext_management_system, :hosts => [@host1, @host2], :zone => @selected_zone)

      @svr1 = FactoryGirl.create(:miq_server, :name => 'svr1', :zone => @selected_zone)
      @svr2 = FactoryGirl.create(:miq_server, :name => 'svr2', :zone => @selected_zone)

      @svr1.vm_scan_host_affinity = [@host1]
      @svr2.vm_scan_host_affinity = [@host2]
      @svr1.vm_scan_storage_affinity = [@storage1]
      @svr2.vm_scan_storage_affinity = [@storage2]

      allow_any_instance_of(MiqServer).to receive_messages(:is_a_proxy? => true)
      allow(MiqServer).to receive(:my_server).and_return(OpenStruct.new('id' => 0, :name => 'name'))

      @smartproxy_affinity_tree = TreeBuilderSmartproxyAffinity.new(:smartproxy_affinity,
                                                                    :smartproxy_affinity_tree,
                                                                    {},
                                                                    true,
                                                                    @selected_zone)
    end

    it 'set init options correctly' do
      tree_options = @smartproxy_affinity_tree.send(:tree_init_options, :smartproxy_affinity)
      expect(tree_options).to eq(:full_ids => false, :add_root => false, :lazy => false)
    end
    it 'set locals for render correctly' do
      locals = @smartproxy_affinity_tree.send(:set_locals_for_render)
      expect(locals[:checkboxes]).to eq(true)
      expect(locals[:check_url]).to eq('/ops/smartproxy_affinity_field_changed/')
      expect(locals[:onclick]).to eq(false)
      expect(locals[:oncheck]).to eq('miqOnClickSmartProxyAffinityCheck')
      expect(locals[:three_checks]).to eq(true)
    end
    it 'sets roots correctly' do
      roots = @smartproxy_affinity_tree.send(:x_get_tree_roots, false)
      expect(roots).to eq([@svr1, @svr2])
    end
    it 'sets MiqServer kids correctly' do
      kids1 = @smartproxy_affinity_tree.send(:x_get_server_kids, @svr1, false)
      kids2 = @smartproxy_affinity_tree.send(:x_get_server_kids, @svr2, false)
      expect(kids1.size).to eq(2)
      expect(kids2.size).to eq(2)
      expect(kids1.first).to eq(:id          => "#{@svr1[:id]}__host",
                                :image       => "100/host.png",
                                :parent      => @svr1,
                                :text        => "Host / Nodes",
                                :cfmeNoClick => true,
                                :children    => @selected_zone.send('host'.pluralize).sort_by(&:name),
                                :smartproxy_kind => "host")
      expect(kids2.first).to eq(:id          => "#{@svr2[:id]}__host",
                                :image       => "100/host.png",
                                :parent      => @svr2,
                                :text        => "Host / Nodes",
                                :cfmeNoClick => true,
                                :children    => @selected_zone.send('host'.pluralize).sort_by(&:name),
                                :smartproxy_kind => "host")
      expect(kids1.last).to eq(:id          => "#{@svr1[:id]}__storage",
                               :image       => "100/storage.png",
                               :parent      => @svr1,
                               :text        => "Datastores",
                               :cfmeNoClick => true,
                               :children    => @selected_zone.send('storage'.pluralize).sort_by(&:name),
                               :smartproxy_kind => "storage")
      expect(kids2.last).to eq(:id          => "#{@svr2[:id]}__storage",
                               :image       => "100/storage.png",
                               :parent      => @svr2,
                               :text        => "Datastores",
                               :cfmeNoClick => true,
                               :children    => @selected_zone.send('storage'.pluralize).sort_by(&:name),
                               :smartproxy_kind => "storage")
    end

    it 'sets Datastores kids correctly' do
      parent1 = @smartproxy_affinity_tree.send(:x_get_server_kids, @svr1, false).first
      parent2 = @smartproxy_affinity_tree.send(:x_get_server_kids, @svr2, false).first
      parent3 = @smartproxy_affinity_tree.send(:x_get_server_kids, @svr1, false).last
      parent4 = @smartproxy_affinity_tree.send(:x_get_server_kids, @svr2, false).last
      parents = [parent1, parent2, parent3, parent4]
      parents.each do |parent|
        kids = @smartproxy_affinity_tree.send(:x_get_tree_hash_kids, parent, false)
        parent[:children].each_with_index do |kid, i|
          expect(kids[i][:image]).to eq(parent[:image])
          expect(kids[i][:text]).to eq(kid.name)
          expect(kids[i][:id]).to eq("#{parent[:id]}_#{kid.id}")
          expect(kids[i][:children]).to eq([])
          expect(kids[i][:select]).to eq( parent[:parent].send("vm_scan_#{parent[:smartproxy_kind]}_affinity").collect(&:id).include?(kid.id))
        end
      end
    end
  end
end
