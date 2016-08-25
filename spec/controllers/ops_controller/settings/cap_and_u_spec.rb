describe OpsController do
  before(:each) do
    MiqRegion.seed
  end

  context '#cu_build_edit_screen' do
    before do
      tree_hash = {
        :trees       => {
          :settings_tree => {
            :active_node => "root"
          }
        },
        :active_tree => :settings_tree,
        :active_tab  => 'settings_cu_collection'
      }
      controller.instance_variable_set(:@sb, tree_hash)
    end

    it 'should have no tree data set when there are no clusters/storage records in db' do
      controller.send(:cu_build_edit_screen)
      expect(assigns(:cluster_tree)).to eq(nil)
      expect(assigns(:datastore_tree)).to eq(nil)
    end

    it 'should have tree data set when there are clusters/storage records in db' do
      FactoryGirl.create(:ems_cluster, :name => "My Cluster")
      FactoryGirl.create(:storage_vmware, :name => "My Datastore")
      controller.send(:cu_build_edit_screen)
      expect(assigns(:cluster_tree)).to_not eq(nil)
      expect(assigns(:datastore_tree)).to_not eq(nil)
    end
  end
end
