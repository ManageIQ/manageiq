describe StorageController do

  let(:storage) { FactoryGirl.create(:storage, :name => 'test_storage1') }
  let(:storage_cluster) { FactoryGirl.create(:storage_cluster, :name => 'test_storage_cluster1') }
  before { set_user_privileges }

  context "#button" do
    it "when VM Right Size Recommendations is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_right_size")
      expect(controller).to receive(:vm_right_size)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Migrate is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_migrate")
      controller.instance_variable_set(:@refresh_partial, "layouts/gtl")
      expect(controller).to receive(:prov_redirect).with("migrate")
      expect(controller).to receive(:render)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Retire is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_retire")
      expect(controller).to receive(:retirevms).once
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Manage Policies is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_protect")
      expect(controller).to receive(:assign_policies).with(VmOrTemplate)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when MiqTemplate Manage Policies is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "miq_template_protect"})
      expect(controller).to receive(:assign_policies).with(VmOrTemplate)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when VM Tag is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "vm_tag")
      expect(controller).to receive(:tag).with(VmOrTemplate)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when MiqTemplate Tag is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "miq_template_tag")
      expect(controller).to receive(:tag).with(VmOrTemplate)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when Host Analyze then Check Compliance is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "host_analyze_check_compliance")
      allow(controller).to receive(:show)
      expect(controller).to receive(:analyze_check_compliance_hosts)
      expect(controller).to receive(:render)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    {"host_standby"  => "Enter Standby Mode",
     "host_shutdown" => "Shut Down",
     "host_reboot"   => "Restart",
     "host_start"    => "Power On",
     "host_stop"     => "Power Off",
     "host_reset"    => "Reset"
    }.each do |button, description|
      it "when Host #{description} button is pressed" do
        login_as FactoryGirl.create(:user, :features => button)

        host = FactoryGirl.create(:host)
        command = button.split('_', 2)[1]
        allow_any_instance_of(Host).to receive(:is_available?).with(command).and_return(true)

        controller.instance_variable_set(:@_params, :pressed => button, :miq_grid_checks => "#{host.id}")
        controller.instance_variable_set(:@lastaction, "show_list")
        allow(controller).to receive(:show_list)
        expect(controller).to receive(:render)
        controller.button
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to include("successfully initiated")
        expect(flash_messages.first[:level]).to eq(:success)
      end
    end
  end

  context 'render_views' do
    render_views

    context '#explorer' do
      before do
        session[:settings] = {:views => {}, :perpage => {:list => 10}}
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it 'can render the explorer' do
        storage
        session[:sb] = {:active_accord => :storage_accord}
        seed_session_trees('storage', :storage_tree, 'root')
        get :explorer
        expect(response.status).to eq(200)
        expect(response.body).to_not be_empty
      end

      it 'shows a datastore in the datastore list' do
        storage
        session[:sb] = {:active_accord => :storage_accord}
        seed_session_trees('storage', :storage_tree, 'root')

        get :explorer
        expect(response.body).to match(%r({"text":\s*"test_storage1"}))
      end

      it 'show a datastore cluster in the datastore clusters list' do
        allow(controller).to receive(:x_node).and_return("root")
        storage
        storage_cluster
        session[:sb] = {:active_accord => :storage_pod_accord}
        seed_session_trees('storage', :storage_pod_tree, 'root')
        get :explorer
        expect(response.body).to include('test_storage_cluster1')
      end
    end

    context "#tree_select" do
      before do
        storage
        storage_cluster
      end

      [
        ['All Datastore Clusters', 'storage_pod_tree'],
      ].each do |elements, tree|
        it "renders list of #{elements} for #{tree} root node" do
          session[:settings] = {}
          seed_session_trees('storage', tree.to_sym)

          post :tree_select, :params => { :id => 'root', :format => :js }
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
