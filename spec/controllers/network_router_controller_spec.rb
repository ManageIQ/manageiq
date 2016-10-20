require Rails.root.join('spec/shared/controllers/shared_examples_for_network_router_controller')

describe NetworkRouterController do
  include_examples :shared_examples_for_network_router_controller, %w(openstack azure google)

  context "#button" do
    before(:each) do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone

      ApplicationController.handle_exceptions = true
    end

    it "when Edit Tag is pressed" do
      # TODO: Fix
      skip "Not ready yet"
      expect(controller).to receive(:tag)
      post :button, :params => { :pressed => "edit_tag", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end
  end

  context "#tags_edit" do
    let!(:user) { stub_user(:features => :all) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ct = FactoryGirl.create(:network_router, :name => "router-01")
      allow(@ct).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@ct).and_return([@tag1, @tag2])
      session[:tag_db] = "NetworkRouter"
      edit = {
        :key        => "NetworkRouter_edit_tags__#{@ct.id}",
        :tagging    => "NetworkRouter",
        :object_ids => [@ct.id],
        :current    => {:assignments => []},
        :new        => {:assignments => [@tag1.id, @tag2.id]}
      }
      session[:edit] = edit
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "builds tagging screen" do
      post :button, :params => { :pressed => "network_router_tag", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "network_router/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "cancel", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "network_router/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "save", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @router = FactoryGirl.create(:network_router)
      login_as FactoryGirl.create(:user)
    end

    subject do
      get :show, :params => {:id => @router.id}
    end

    context "render listnav partial" do
      render_views
      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_network_router")
      end
    end
  end

  describe "#create" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack).network_manager
      @router = FactoryGirl.create(:network_router_openstack)
    end

    context "#create" do
      let(:task_options) do
        {
          :action => "creating Network Router for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @ems.class.name,
          :method_name => 'create_network_router',
          :instance_id => @ems.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => 'ems_operations',
          :zone        => @ems.my_zone,
          :args        => [{:name => "test"}]
        }
      end

      it "builds create screen" do
        post :button, :params => { :pressed => "network_router_new", :format => :js }
        expect(assigns(:flash_array)).to be_nil
      end

      it "queues the create action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :create, :params => { :button => "add", :format => :js, :name => 'test',
                                   :tenant_id => 'id', :ems_id => @ems.id }
      end
    end
  end

  describe "#edit" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack).network_manager
      @router = FactoryGirl.create(:network_router_openstack,
                                   :ext_management_system => @ems)
    end

    context "#edit" do
      let(:task_options) do
        {
          :action => "updating Network Router for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @router.class.name,
          :method_name => 'update_network_router',
          :instance_id => @router.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => 'ems_operations',
          :zone        => @ems.my_zone,
          :args        => [{:name => "foo2"}]
        }
      end

      it "builds edit screen" do
        post :button, :params => { :pressed => "network_router_edit", :format => :js, :id => @router.id }
        expect(assigns(:flash_array)).to be_nil
      end

      it "queues the update action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :update, :params => { :button => "save", :format => :js, :id => @router.id, :name => "foo2" }
      end
    end
  end

  describe "#delete" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack).network_manager
      @router = FactoryGirl.create(:network_router_openstack,
                                   :ext_management_system => @ems)
    end

    context "#delete" do
      let(:task_options) do
        {
          :action => "deleting Network Router for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @router.class.name,
          :method_name => 'delete_network_router',
          :instance_id => @router.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => 'ems_operations',
          :zone        => @ems.my_zone,
          :args        => []
        }
      end

      it "queues the delete action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :button, :params => { :id => @router.id, :pressed => "network_router_delete", :format => :js }
      end
    end
  end
end
