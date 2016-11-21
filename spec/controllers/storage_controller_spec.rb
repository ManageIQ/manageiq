describe StorageController do
  include CompressedIds

  let(:storage) { FactoryGirl.create(:storage, :name => 'test_storage1') }
  let(:storage_cluster) { FactoryGirl.create(:storage_cluster, :name => 'test_storage_cluster1') }
  before { stub_user(:features => :all) }

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

        controller.instance_variable_set(:@_params, :pressed => button, :miq_grid_checks => host.id.to_s)
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
        session[:settings] = {:views => {}, :perpage => {:list => 5}}
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it 'can render the explorer' do
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

      it 'can render the second page of datastores' do
        7.times do |i|
          FactoryGirl.create(:storage, :name => 'test_storage' % i)
        end
        session[:sb] = {:active_accord => :storage_accord}
        seed_session_trees('storage', :storage_tree, 'root')
        allow(controller).to receive(:current_page).and_return(2)
        get :explorer, :params => {:page => '2'}
        expect(response.status).to eq(200)
        expect(response.body).to include("<li>\n<span>\nShowing 6-7 of 7 items\n<input name='limitstart' type='hidden' value='0'>\n</span>\n</li>")
      end

      it "it handles x_button tagging" do
        ems = FactoryGirl.create(:ems_vmware)
        datastore = FactoryGirl.create(:storage, :name => 'storage_name')
        datastore.parent = ems
        classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
        @tag1 = FactoryGirl.create(:classification_tag,
                                   :name   => "tag1",
                                   :parent => classification
        )
        @tag2 = FactoryGirl.create(:classification_tag,
                                   :name   => "tag2",
                                   :parent => classification
        )
        allow(Classification).to receive(:find_assigned_entries).and_return([@tag1, @tag2])
        post :x_button, :params => {:miq_grid_checks => to_cid(datastore.id), :pressed => "storage_tag", :format => :js}
        expect(response.status).to eq(200)

        main_content = JSON.parse(response.body)['updatePartials']['main_div']
        expect(main_content).to include("<h3>\n1 Datastore Being Tagged\n<\/h3>")
      end

      it 'can Perform a datastore Smart State Analysis from the datastore summary page' do
        allow(controller).to receive(:x_node).and_return("ds-#{storage.compressed_id}")
        post :x_button, :params => {:pressed => 'storage_scan', :id => storage.id}
        expect(response.status).to eq(200)
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to_not include("Datastores no longer exists")
      end

      it 'can Perform a datastore Smart State Analysis from the datastore list' do
        storage
        seed_session_trees('storage', :storage_tree, 'root')
        get :explorer
        post :x_button, :params => {:pressed => 'storage_scan', :miq_grid_checks => to_cid(storage.id), :format => :js}
        expect(response.status).to eq(200)
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to_not include("Datastores no longer exists")
      end

      it 'can Perform a datastore Smart State Analysis from the datastore cluster list' do
        storage
        storage_cluster
        seed_session_trees('storage', :storage_pod_tree, 'root')
        post :tree_select, :params => {:id => "xx-#{to_cid(storage_cluster.id)}", :format => :js}
        expect(response.status).to eq(200)
        post :x_button, :params => {:pressed => 'storage_scan', :miq_grid_checks => to_cid(storage.id), :format => :js}
        expect(response.status).to eq(200)
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to_not include("Datastores no longer exists")
      end

      it 'can Perform a remove datastore from the datastore cluster list' do
        storage
        storage_cluster
        seed_session_trees('storage', :storage_pod_tree, 'root')
        post :tree_select, :params => {:id => "xx-#{to_cid(storage_cluster.id)}", :format => :js}
        expect(response.status).to eq(200)
        post :x_button, :params => {:pressed         => 'storage_delete',
                                    :miq_grid_checks => to_cid(storage.id),
                                    :format          => :js}
        expect(response.status).to eq(200)
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to_not include("Datastores no longer exists")
      end

      it 'can render datastore details' do
        tree_node_id = TreeBuilder.build_node_id(storage)
        session[:sandboxes] = {} # no prior data in @sb
        session[:exp_parms] = {:controller => 'storage',
                               :action     => 'show',
                               :id         => tree_node_id}

        get :explorer
        expect(response.status).to eq(200)
        expect(response.body).to_not be_empty
        expect(response).to render_template('shared/summary/_textual')
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

  context "#tags_edit" do
    let!(:user) { stub_user(:features => :all) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ds = FactoryGirl.create(:storage, :name => "Datastore-01")
      allow(@ds).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@ds).and_return([@tag1, @tag2])
      session[:tag_db] = "Storage"
      edit = {
        :key        => "Storage_edit_tags__#{@ds.id}",
        :tagging    => "Storage",
        :object_ids => [@ds.id],
        :current    => {:assignments => []},
        :new        => {:assignments => [@tag1.id, @tag2.id]}
      }
      session[:edit] = edit
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "builds tagging screen" do
      post :button, :params => {:pressed => "storage_tag", :format => :js, :id => @ds.id}
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "storage/x_show/#{@ds.id}"}, 'placeholder']
      post :tagging_edit, :params => {:button => "cancel", :format => :js, :id => @ds.id}
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "storage/x_show/#{@ds.id}"}, 'placeholder']
      post :tagging_edit, :params => {:button => "save", :format => :js, :id => @ds.id}
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end

    it "resets tags" do
      session[:breadcrumbs] = [{:url => "storage/x_show/#{@ds.id}"}, 'placeholder']
      session[:assigned_filters] = []
      post :tagging_edit, :params => {:button => "reset", :format => :js, :id => @ds.id}
      expect(assigns(:flash_array).first[:message]).to include("All changes have been reset")
    end
  end
end
