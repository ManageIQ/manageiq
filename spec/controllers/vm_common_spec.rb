describe VmOrTemplateController do
  context "#snap_pressed" do
    before :each do
      set_user_privileges
      allow(controller).to receive(:role_allows).and_return(true)
      vm = FactoryGirl.create(:vm_vmware)
      @snapshot = FactoryGirl.create(:snapshot, :vm_or_template_id => vm.id,
                                                :name              => 'EvmSnapshot',
                                                :description       => "Some Description"
                                    )
      vm.snapshots = [@snapshot]
      tree_hash = {
        :trees       => {
          :vandt_tree => {
            :active_node => "v-#{vm.id}"
          }
        },
        :active_tree => :vandt_tree
      }

      session[:sandboxes] = {"vm_or_template" => tree_hash}
    end

    it "snapshot node exists in tree" do
      post :snap_pressed, :params => { :id => @snapshot.id }
      expect(assigns(:flash_array)).to be_blank
    end

    it "when snapshot is selected center toolbars are replaced" do
      post :snap_pressed, :params => { :id => @snapshot.id }
      expect(response.body).to include("center_tb")
      expect(assigns(:flash_array)).to be_blank
    end

    it "deleted node pressed in snapshot tree" do
      post :snap_pressed, :params => { :id => "some_id" }
      expect(assigns(:flash_array).first[:message]).to eq("Last selected Snapshot no longer exists")
      expect(assigns(:flash_array).first[:level]).to eq(:error)
    end
  end

  context "#show" do
    before :each do
      allow(User).to receive(:server_timezone).and_return("UTC")
      allow_any_instance_of(described_class).to receive(:set_user_time_zone)
      allow(controller).to receive(:check_privileges).and_return(true)
      EvmSpecHelper.seed_specific_product_features("vandt_accord", "vms_instances_filter_accord")
      @vm = FactoryGirl.create(:vm_vmware)
    end

    it "redirects user to explorer that they have access to" do
      feature = MiqProductFeature.find_all_by_identifier(["vandt_accord"])
      login_as FactoryGirl.create(:user, :features => feature)
      controller.instance_variable_set(:@sb, {})
      get :show, :params => {:id => @vm.id}
      expect(response).to redirect_to(:controller => "vm_infra", :action => 'explorer')
    end

    it "redirects user to Workloads explorer when user does not have access to Infra Explorer" do
      feature = MiqProductFeature.find_all_by_identifier(["vms_instances_filter_accord"])
      login_as FactoryGirl.create(:user, :features => feature)
      controller.instance_variable_set(:@sb, {})
      get :show, :params => {:id => @vm.id}
      expect(response).to redirect_to(:controller => "vm_or_template", :action => 'explorer')
    end

    it "redirects user back to the url they came from when user does not have access to any of VM Explorers" do
      feature = MiqProductFeature.find_all_by_identifier(["dashboard_show"])
      login_as FactoryGirl.create(:user, :features => feature)
      controller.instance_variable_set(:@sb, {})
      request.env["HTTP_REFERER"] = "http://localhost:3000/dashboard/show"
      get :show, :params => {:id => @vm.id}
      expect(response).to redirect_to(:controller => "dashboard", :action => 'show')
      expect(assigns(:flash_array).first[:message]).to include("is not authorized to access")
    end

    it "Redirects user with privileges to vm_infra/explorer" do
      set_user_privileges
      get :show, :params => {:id => @vm.id}
      expect(response.status).to eq(302)
      expect(response).to redirect_to(:controller => "vm_infra", :action => 'explorer')
    end

    it "Redirects user to the referrer controller/action" do
      login_as FactoryGirl.create(:user)
      request.env["HTTP_REFERER"] = "http://localhost:3000/dashboard/show"
      allow(controller).to receive(:find_by_id_filtered).and_return(nil)
      get :show, :params => {:id => @vm.id}
      expect(response.status).to eq(302)
      expect(response).to redirect_to(:controller => "dashboard", :action => 'show')
    end
  end

  describe '#console_after_task' do
    let(:vm) { FactoryGirl.create(:vm_vmware) }
    let(:task) { FactoryGirl.create(:miq_task, :task_results => task_results) }
    subject { controller.send(:console_after_task, 'html5') }

    before(:each) do
      controller.instance_variable_set(:@_response, ActionDispatch::TestResponse.new)
    end

    context 'console with websocket URL' do
      let(:url) { '/ws/console/123456' }
      let(:task_results) { {:url => url} }

      it 'renders javascript to open a popup' do
        allow(controller).to receive(:params).and_return(:task_id => task.id)
        expect(subject).to include("window.open('/vm_or_template/launch_html5_console?#{task_results.to_query}');")
      end
    end

    context 'console with remote URL' do
      let(:url) { 'http://www.manageiq.org' }
      let(:task_results) { {:remote_url => url} }

      it 'renders javascript to open a popup' do
        expect(controller).to receive(:params).and_return(:task_id => task.id)
        expect(subject).to include("window.open('#{url}');")
      end
    end
  end

  context '#replace_right_cell' do
    it 'should display form button on Migrate request screen' do
      vm = FactoryGirl.create(:vm_infra)
      allow(controller).to receive(:params).and_return(:action => 'vm_migrate')
      controller.instance_eval { @sb = {:active_tree => :vandt_tree, :action => "migrate"} }
      controller.instance_eval { @record = vm }
      controller.instance_eval { @in_a_form = true }
      allow(controller).to receive(:render).and_return(nil)
      presenter = ExplorerPresenter.new(:active_tree => :vandt_tree)
      expect(controller).to receive(:render_to_string).with(:partial => "miq_request/prov_edit",
                                                             :locals => {:controller => "vm"}).exactly(1).times
      expect(controller).to receive(:render_to_string).with(:partial => "layouts/x_adv_searchbox",
                                                             :locals => {:nameonly => true}).exactly(1).times
      expect(controller).to receive(:render_to_string).with(:partial => "layouts/x_edit_buttons",
                                                             :locals => {:action_url      => "prov_edit",
                                                                         :record_id       => vm.id,
                                                                         :no_reset        => true,
                                                                         :submit_button   => true,
                                                                         :continue_button => false}).exactly(1).times
      controller.send(:replace_right_cell, 'migrate', presenter)
      expect(presenter[:update_partials]).to have_key(:form_buttons_div)
    end
  end
end
