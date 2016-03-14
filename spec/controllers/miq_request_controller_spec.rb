describe MiqRequestController do
  context "#post_install_callback should render nothing" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
    end

    it "when called with a task id" do
      expect(MiqRequestTask).to receive(:post_install_callback).with("12345").once
      get 'post_install_callback', :params => { :task_id => 12345 }
      expect(response.body).to be_blank
    end

    it "when called without a task id" do
      expect(MiqRequestTask).not_to receive(:post_install_callback)
      get 'post_install_callback'
      expect(response.body).to be_blank
    end
  end

  describe "#get_view" do
    let(:parent_tenant)      { FactoryGirl.create(:tenant) }
    let(:child_tenant)       { FactoryGirl.create(:tenant, :parent=> parent_tenant) }
    let(:user_child_tenant)  { FactoryGirl.create(:user_with_group, :tenant => child_tenant) }
    let(:user_parent_tenant) { FactoryGirl.create(:user_with_group, :tenant => parent_tenant) }

    let(:template)     { FactoryGirl.create(:template_amazon) }
    let(:request_body) { {:requester => user_child_tenant, :source_type => 'VmOrTemplate', :source_id => template.id} }

    before :each do
      EvmSpecHelper.local_miq_server

      login_as user_child_tenant
      FactoryGirl.create(:miq_provision_request, request_body)
    end

    it "displays miq_request for parent_tenant, when request was added by child_parent" do
      login_as user_parent_tenant
      controller.instance_variable_set(:@settings, {})
      allow_any_instance_of(MiqRequestController).to receive(:listicon_image)

      view, _pages = controller.send(:get_view, MiqRequest, {})
      expect(view.table.data.count).to eq(1)
    end
  end

  context "#prov_condition builds correct MiqExpression hash" do
    let(:user) { FactoryGirl.create(:user_admin) }
    before { login_as user }

    it "MiqRequest-created_on" do
      content = {"value" => "9 Days Ago", "field" => "MiqRequest-created_on"}
      expect(MiqExpression).to receive(:new) do |h|
        expect(h.fetch_path("and", 0, "AFTER")).to eq(content)
      end
      controller.send(:prov_condition, :time_period => 9)
    end

    context "MiqRequest-requester_id set based on user_id" do
      it "user with approver priveleges" do
        content = {"value" => user.id, "field" => "MiqRequest-requester_id"}
        expect(MiqExpression).to receive(:new) do |h|
          expect(h.fetch_path("and", 1, "=")).to eq(content)
        end
        controller.send(:prov_condition, {})
      end

      it "user without approver priveleges" do
        user             = FactoryGirl.create(:user)
        login_as user
        content          = {"value" => user.id, "field" => "MiqRequest-requester_id"}
        expect(MiqExpression).to receive(:new) do |h|
          expect(h.fetch_path("and", 1, "=")).to eq(content)
        end
        controller.send(:prov_condition, {})
      end
    end

    context "MiqRequest-requester_id set based on user_choice" do
      let(:path) { ["and", 2, "=", "value"] }

      it "selected 'all'" do
        expect(MiqExpression).to receive(:new) do |h|
          expect(h.fetch_path(path) == "all").to be_falsey
        end
        controller.send(:prov_condition, :user_choice => "all")
      end

      it "selected '1'" do
        expect(MiqExpression).to receive(:new) do |h|
          expect(h.fetch_path(path) == 1).to be_truthy
        end
        controller.send(:prov_condition, :user_choice => 1)
      end
    end

    it "MiqRequest-approval_state set with :applied_states" do
      content = [{"=" => {"value" => "state", "field" => "MiqRequest-approval_state"}}, {"=" => {"value" => "state 2", "field" => "MiqRequest-approval_state"}}]
      expect(MiqExpression).to receive(:new) do |h|
        expect(h.fetch_path("and", 2, "or")).to eq(content)
      end
      controller.send(:prov_condition, :applied_states => ["state", "state 2"])
    end

    it "MiqRequest-resource_type" do
      content = %w(MiqProvisionRequest MiqProvisionConfiguredSystemRequest VmReconfigureRequest VmMigrateRequest ServiceTemplateProvisionRequest ServiceReconfigureRequest).collect do |type|
        {"=" => {"value" => type, "field" => "MiqRequest-resource_type"}}
      end

      expect(MiqExpression).to receive(:new) do |h|
        expect(h.fetch_path("and", 2, "or")).to eq(content)
      end
      controller.send(:prov_condition, {})
    end

    context "MiqRequest-request_type set based on type_choice" do
      let(:path) { ["and", 3, "=", "value"] }

      it "selected 'all'" do
        expect(MiqExpression).to receive(:new) do |h|
          expect(h.fetch_path(path)).to be_nil
        end
        controller.send(:prov_condition, :type_choice => "all")
      end

      it "selected '1'" do
        expect(MiqExpression).to receive(:new) do |h|
          expect(h.fetch_path(path)).to eq(1)
        end
        controller.send(:prov_condition, :type_choice => 1)
      end
    end

    it "MiqRequest-reason_text" do
      content = {"value" => "just because", "field" => "MiqRequest-reason"}
      expect(MiqExpression).to receive(:new) do |h|
        expect(h.fetch_path("and", 3, "INCLUDES")).to eq(content)
      end
      controller.send(:prov_condition, :reason_text => "just because")
    end

    it "empty options hash" do
      expect(MiqExpression).to receive(:new) do |h|
        expect(h.fetch_path("and", 2, "or", 0, "=", "field") == "MiqRequest-approval_state")
          .to be_falsey # Doesn't set approval_states
        expect(h.fetch_path("and", 3, "INCLUDES")).to be_nil # Doesn't set reason_text
      end
      controller.send(:prov_condition, {})
    end
  end

  context "#button" do
    before(:each) do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone
      @miq_request = MiqProvisionConfiguredSystemRequest.create(:description    => "Foreman provision",
                                                                :approval_state => "pending_approval",
                                                                :requester      => User.current_user)
    end
    it "when edit request button is pressed" do
      post :button, :params => { :pressed => "miq_request_edit", :id => @miq_request.id, :format => :js }
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end

    it "when copy request button is pressed" do
      post :button, :params => { :pressed => "miq_request_copy", :id => @miq_request.id, :format => :js }
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end
  end

  render_views
  context "#edit_button" do
    before do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone
      @miq_request = MiqProvisionConfiguredSystemRequest.create(:description    => "Foreman provision",
                                                                :approval_state => "pending_approval",
                                                                :requester      => User.current_user)
    end
    it "when the edit button is pressed the request is displayed" do
      session[:settings] = {:display   => {:quad_truncate => 'f'}}
      get :show, :params => { :id => @miq_request.id }
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end
  end

  context "#layout_from_tab_name" do
    before do
      set_user_privileges
      EvmSpecHelper.create_guid_miq_server_zone
      session[:settings] = {:display   => {:quad_truncate => 'f'},
                            :views     => {:miq_request => 'grid'}}
    end

    it "miq_request/show_list sets @layout='miq_request_vm' when redirected via foreman provisioning" do
      post :show_list, :params => { :typ => "configured_systems" }
      layout = controller.instance_variable_get(:@layout)
      expect(layout).to eq("miq_request_vm")
    end
  end
end
