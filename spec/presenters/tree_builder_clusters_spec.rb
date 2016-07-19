describe TreeBuilderClusters do
  context 'TreeBuilderClusters' do
    before do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Clusters Group")
      login_as FactoryGirl.create(:user, :userid => 'clusters__wilma', :miq_groups => [@group])
      allow(EmsCluster).to receive(:get_perf_collection_object_list).and_return('TODO')
      @cluster = [{:id => 1, :name => 'Name', :capture => true, :ho_enabled => [], :ho_disabled => []}]
      @cluster_tree = TreeBuilderClusters.new(:cluster, :cluster_tree, {}, true, @cluster)
    end
    it 'sets tree to have full ids, not lazy and no root' do
      binding.pry
      root_options = @cluster_tree.send(:tree_init_options, nil)
      expect(root_options).to eq({:full_ids => false, :add_root => false, :lazy => false})
    end
  end
end
