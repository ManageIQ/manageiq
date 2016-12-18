describe CloudTenantController do
  context "#button" do
    before(:each) do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone

      ApplicationController.handle_exceptions = true
    end

    it "when Instance Retire button is pressed" do
      expect(controller).to receive(:retirevms).once
      post :button, :params => { :pressed => "instance_retire", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    it "when Instance Tag is pressed" do
      expect(controller).to receive(:tag).with(VmOrTemplate)
      post :button, :params => { :pressed => "instance_tag", :format => :js }
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end
  end

  context "#tags_edit" do
    let!(:user) { stub_user(:features => :all) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ct = FactoryGirl.create(:cloud_tenant, :name => "cloud-tenant-01")
      allow(@ct).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@ct).and_return([@tag1, @tag2])
      session[:tag_db] = "CloudTenant"
      edit = {
        :key        => "CloudTenant_edit_tags__#{@ct.id}",
        :tagging    => "CloudTenant",
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
      post :button, :params => { :pressed => "cloud_tenant_tag", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "cloud_tenant/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "cancel", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "cloud_tenant/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "save", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @tenant = FactoryGirl.create(:cloud_tenant)
      login_as FactoryGirl.create(:user)
    end

    subject do
      get :show, :params => {:id => @tenant.id}
    end

    context "render listnav partial" do
      render_views
      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_cloud_tenant")
      end
    end
  end

  describe "#create" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack)
      @tenant = FactoryGirl.create(:cloud_tenant_openstack)
    end

    context "#create" do
      let(:task_options) do
        {
          :action => "creating Cloud Tenant for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => CloudTenant.class_by_ems(@ems),
          :method_name => "create_cloud_tenant",
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "ems_operations",
          :zone        => @ems.my_zone,
          :args        => [@ems.id, {:name => "foo" }]
        }
      end

      it "builds create screen" do
        post :button, :params => { :pressed => "cloud_tenant_new", :format => :js }
        expect(assigns(:flash_array)).to be_nil
      end

      it "queues the create action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :create, :params => { :button => "add", :format => :js, :name => 'foo', :ems_id => @ems.id }
      end
    end
  end

  describe "#edit" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack)
      @tenant = FactoryGirl.create(:cloud_tenant_openstack,
                                   :ext_management_system => @ems)
    end

    context "#edit" do
      let(:task_options) do
        {
          :action => "updating Cloud Tenant for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @tenant.class.name,
          :method_name => "update_cloud_tenant",
          :instance_id => @tenant.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "ems_operations",
          :zone        => @ems.my_zone,
          :args        => [{:name => "foo"}]
        }
      end

      it "builds edit screen" do
        post :button, :params => { :pressed => "cloud_tenant_edit", :format => :js, :id => @tenant.id }
        expect(assigns(:flash_array)).to be_nil
      end

      it "queues the update action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :update, :params => { :button => "save", :format => :js, :id => @tenant.id, :name => "foo" }
      end
    end
  end

  describe "#delete" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack)
      @tenant = FactoryGirl.create(:cloud_tenant_openstack,
                                   :ext_management_system => @ems)
    end

    context "#edit" do
      let(:task_options) do
        {
          :action => "deleting Cloud Tenant for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @tenant.class.name,
          :method_name => "delete_cloud_tenant",
          :instance_id => @tenant.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "ems_operations",
          :zone        => @ems.my_zone,
          :args        => []
        }
      end

      it "queues the delete action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :button, :params => { :id => @tenant.id, :pressed => "cloud_tenant_delete", :format => :js }
      end
    end
  end
end
