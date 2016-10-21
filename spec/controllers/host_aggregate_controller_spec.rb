describe HostAggregateController do
  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @aggregate = FactoryGirl.create(:host_aggregate)
      login_as FactoryGirl.create(:user_admin)
    end

    subject do
      get :show, :params => {:id => @aggregate.id}
    end

    context "render listnav partial" do
      render_views

      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => "layouts/listnav/_host_aggregate")
      end
    end
  end

  describe "#create" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack)
      @aggregate = FactoryGirl.create(:host_aggregate_openstack)
    end

    context "#create" do
      let(:task_options) do
        {
          :action => "creating Host Aggregate for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @aggregate.class.name,
          :method_name => "create_aggregate",
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "ems_operations",
          :zone        => @ems.my_zone,
          :args        => [@ems.id, {:name => "foo", :ems_id => @ems.id.to_s }]
        }
      end

      it "builds create screen" do
        post :button, :params => { :pressed => "host_aggregate_new", :format => :js }
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
      @aggregate = FactoryGirl.create(:host_aggregate_openstack,
                                      :ext_management_system => @ems)
    end

    context "#edit" do
      let(:task_options) do
        {
          :action => "updating Host Aggregate for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @aggregate.class.name,
          :method_name => "update_aggregate",
          :instance_id => @aggregate.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "ems_operations",
          :zone        => @ems.my_zone,
          :args        => [{:name => "foo"}]
        }
      end

      it "builds edit screen" do
        post :button, :params => { :pressed => "host_aggregate_edit", :format => :js, :id => @aggregate.id }
        expect(assigns(:flash_array)).to be_nil
      end

      it "queues the update action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :update, :params => { :button => "save", :format => :js, :id => @aggregate.id, :name => "foo" }
      end
    end
  end

  describe "#delete" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack)
      @aggregate = FactoryGirl.create(:host_aggregate_openstack,
                                      :ext_management_system => @ems)
    end

    context "#edit" do
      let(:task_options) do
        {
          :action => "deleting Host Aggregate for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @aggregate.class.name,
          :method_name => "delete_aggregate",
          :instance_id => @aggregate.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "ems_operations",
          :zone        => @ems.my_zone,
          :args        => []
        }
      end

      it "queues the delete action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :button, :params => { :id => @aggregate.id, :pressed => "host_aggregate_delete", :format => :js }
      end
    end
  end
end
