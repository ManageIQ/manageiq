describe CloudVolumeSnapshotController do
  context "#tags_edit" do
    let!(:user) { stub_user(:features => :all) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @snapshot = FactoryGirl.create(:cloud_volume_snapshot, :name => "cloud-volume-snapshot-01")
      allow(@snapshot).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "D    epartment")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@snapshot).and_return([@tag1, @tag2])
      session[:tag_db] = "CloudVolumeSnapshot"
      edit = {
        :key        => "CloudVolumeSnapshot_edit_tags__#{@snapshot.id}",
        :tagging    => "CloudVolumeSnapshot",
        :object_ids => [@snapshot.id],
        :current    => {:assignments => []},
        :new        => {:assignments => [@tag1.id, @tag2.id]}
      }
      session[:edit] = edit
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "builds tagging screen" do
      post :button, :params => {:pressed => "cloud_volume_snapshot_tag", :format => :js, :id => @snapshot.id}
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "cloud_volume_snapshot/show/#{@snapshot.id}"}, 'placeholder']
      post :tagging_edit, :params => {:button => "cancel", :format => :js, :id => @snapshot.id}
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "cloud_volume_snapshot/show/#{@snapshot.id}"}, 'placeholder']
      post :tagging_edit, :params => {:button => "save", :format => :js, :id => @snapshot.id}
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#delete" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack)
      @snapshot = FactoryGirl.create(:cloud_volume_snapshot_openstack,
                                     :ext_management_system => @ems)
    end

    context "#delete" do
      let(:task_options) do
        {
          :action => "deleting volume snapshot #{@snapshot.inspect} in #{@ems.inspect}",
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @snapshot.class.name,
          :instance_id => @snapshot.id,
          :method_name => 'delete_snapshot',
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => 'ems_operations',
          :zone        => @ems.my_zone,
          :args        => []
        }
      end

      it "queues the delete action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :button, :params => { :id => @snapshot.id, :pressed => "cloud_volume_snapshot_delete", :format => :js }
      end
    end
  end
end
