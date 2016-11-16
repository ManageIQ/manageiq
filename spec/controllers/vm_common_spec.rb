describe VmOrTemplateController do
  context "#snap_pressed" do
    before :each do
      stub_user(:features => :all)
      @vm = FactoryGirl.create(:vm_vmware)
      @snapshot = FactoryGirl.create(:snapshot, :vm_or_template_id => @vm.id,
                                                :name              => 'EvmSnapshot',
                                                :description       => "Some Description"
                                    )
      @vm.snapshots = [@snapshot]
      tree_hash = {
        :trees       => {
          :vandt_tree => {
            :active_node => "v-#{@vm.id}"
          }
        },
        :active_tree   => :vandt_tree,
        :active_accord => :vandt
      }

      session[:sandboxes] = {"vm_or_template" => tree_hash}
    end

    it "snapshot node exists in tree" do
      post :snap_pressed, :params => { :id => @snapshot.id }
      expect(assigns(:flash_array)).to be_blank
    end

    it "when snapshot is selected center toolbars are replaced" do
      post :snap_pressed, :params => { :id => @snapshot.id }
      expect(response.body).to include("sendDataWithRx({redrawToolbar:")
      expect(assigns(:flash_array)).to be_blank
    end

    it "when snapshot is selected parent vm record remains the same" do
      sb = session[:sandboxes]["vm_or_template"]
      sb[sb[:active_accord]] = "v-#{@vm.id}"
      sb[:trees][:vandt_tree][:active_node] = "f-1"
      post :snap_pressed, :params => { :id => @snapshot.id }
      expect(assigns(:record).id).to eq(@vm.id)
    end

    it "deleted node pressed in snapshot tree" do
      post :snap_pressed, :params => { :id => "some_id" }
      expect(assigns(:flash_array).first[:message]).to eq("Last selected Snapshot no longer exists")
      expect(assigns(:flash_array).first[:level]).to eq(:error)
    end
  end

  context '#reload ' do
    before do
      login_as FactoryGirl.create(:user_with_group, :role => "operator")
      allow(controller).to receive(:tree_select).and_return(nil)
      @folder = FactoryGirl.create(:ems_folder)
      @vm = FactoryGirl.create(:vm_cloud)
    end

    it 'sets params[:id] to hidden vm if its summary is displayed' do
      User.current_user.settings[:display] = {:display_vms => false}
      allow(controller).to receive(:x_node).and_return('f-' + @folder.id.to_s)
      controller.instance_variable_set(:@_params, :id => @vm.id.to_s)
      controller.reload
      expect(controller.params[:id]).to eq('v-' + TreeBuilder.to_cid(@vm.id))
    end

    it 'sets params[:id] to x_node if vms are displayed in a tree' do
      User.current_user.settings[:display] = {:display_vms => true}
      allow(controller).to receive(:x_node).and_return('f-' + @folder.id.to_s)
      controller.instance_variable_set(:@_params, :id => @folder.id.to_s)
      controller.reload
      expect(controller.params[:id]).to eq(controller.x_node)
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
      stub_user(:features => :all)
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
        expect(subject).to match(%r{openUrl.*/vm_or_template/launch_html5_console\?#{task_results.to_query}"})
      end
    end

    context 'console with remote URL' do
      let(:url) { 'http://www.manageiq.org' }
      let(:task_results) { {:remote_url => url} }

      it 'renders javascript to open a popup' do
        expect(controller).to receive(:params).and_return(:task_id => task.id)
        expect(subject).to include("openUrl\":\"#{url}\"")
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

  context '#parent_folder_id' do
    it 'returns id of orphaned folder for orphaned VM/Template' do
      vm_orph = FactoryGirl.create(:vm_infra, :storage => FactoryGirl.create(:storage))
      template_orph = FactoryGirl.create(:template_infra, :storage => FactoryGirl.create(:storage))
      expect(controller.parent_folder_id(vm_orph)).to eq('xx-orph')
      expect(controller.parent_folder_id(template_orph)).to eq('xx-orph')
    end

    it 'returns id of archived folder for archived VM/Template' do
      vm_arch = FactoryGirl.create(:vm_infra)
      template_arch = FactoryGirl.create(:template_infra)
      expect(controller.parent_folder_id(vm_arch)).to eq('xx-arch')
      expect(controller.parent_folder_id(template_arch)).to eq('xx-arch')
    end

    it 'returns id of Availability Zone folder for Cloud VM that has one' do
      vm_cloud_with_az = FactoryGirl.create(:vm_cloud,
                                            :ext_management_system => FactoryGirl.create(:ems_google),
                                            :storage               => FactoryGirl.create(:storage),
                                            :availability_zone     => FactoryGirl.create(:availability_zone_google))
      expect(controller.parent_folder_id(vm_cloud_with_az)).to eq(TreeBuilder.build_node_cid(vm_cloud_with_az.availability_zone))
    end

    it 'returns id of Provider folder for Cloud VM without Availability Zone' do
      vm_cloud_without_az = FactoryGirl.create(:vm_cloud,
                                               :ext_management_system => FactoryGirl.create(:ems_google),
                                               :storage               => FactoryGirl.create(:storage),
                                               :availability_zone     => nil)
      expect(controller.parent_folder_id(vm_cloud_without_az)).to eq(TreeBuilder.build_node_cid(vm_cloud_without_az.ext_management_system))
    end

    it 'returns id of Provider folder for Cloud Template' do
      template_cloud = FactoryGirl.create(:template_cloud,
                                          :ext_management_system => FactoryGirl.create(:ems_google),
                                          :storage               => FactoryGirl.create(:storage))
      expect(controller.parent_folder_id(template_cloud)).to eq(TreeBuilder.build_node_cid(template_cloud.ext_management_system))
    end

    it 'returns id of Provider folder for infra VM/Template without blue folder' do
      vm_infra = FactoryGirl.create(:vm_infra, :ext_management_system => FactoryGirl.create(:ems_infra))
      template_infra = FactoryGirl.create(:template_infra, :ext_management_system => FactoryGirl.create(:ems_infra))
      expect(controller.parent_folder_id(vm_infra)).to eq(TreeBuilder.build_node_cid(vm_infra.ext_management_system))
      expect(controller.parent_folder_id(template_infra)).to eq(TreeBuilder.build_node_cid(template_infra.ext_management_system))
    end

    it 'returns id of blue folder for VM/Template with one' do
      folder = FactoryGirl.create(:ems_folder)
      vm_infra_folder = FactoryGirl.create(:vm_infra, :ext_management_system => FactoryGirl.create(:ems_infra))
      vm_infra_folder.with_relationship_type("ems_metadata") { vm_infra_folder.parent = folder } # add folder
      template_infra_folder = FactoryGirl.create(:template_infra,
                                                 :ext_management_system => FactoryGirl.create(:ems_infra))
      template_infra_folder.with_relationship_type("ems_metadata") { template_infra_folder.parent = folder } # add folder
      expect(controller.parent_folder_id(vm_infra_folder)).to eq(TreeBuilder.build_node_cid(folder))
      expect(controller.parent_folder_id(template_infra_folder)).to eq(TreeBuilder.build_node_cid(folder))
    end
  end

  context "#resolve_node_info" do
    let(:vm_common) do
      Class.new do
        extend VmCommon
        extend CompressedIds
      end
    end
    before do
      login_as FactoryGirl.create(:user_with_group, :role => "operator")
      @vm_arch = FactoryGirl.create(:vm)
    end

    it 'when VM hidden select parent in tree but show VMs info' do
      User.current_user.settings[:display] = {:display_vms => false}

      allow(vm_common).to receive(:x_node=) { |id| expect(id).to eq(controller.parent_folder_id(@vm_arch)) }
      allow(vm_common).to receive(:get_node_info) { |id| expect(id).to eq(TreeBuilder.build_node_cid(@vm_arch)) }
      vm_common.resolve_node_info("v-#{@vm_arch[:id]}")
    end

    it 'when VM shown select it in tree and show its info' do
      User.current_user.settings[:display] = {:display_vms => true}

      allow(vm_common).to receive(:x_node=) { |id| expect(id).to eq(TreeBuilder.build_node_cid(@vm_arch)) }
      allow(vm_common).to receive(:get_node_info) { |id| expect(id).to eq(TreeBuilder.build_node_cid(@vm_arch)) }
      vm_common.resolve_node_info("v-#{@vm_arch[:id]}")
    end
  end
end
