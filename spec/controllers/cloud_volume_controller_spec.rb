describe CloudVolumeController do
  context "#tags_edit" do
    let!(:user) { stub_user(:features => :all) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @volume = FactoryGirl.create(:cloud_volume, :name => "cloud-volume-01")
      allow(@volume).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@volume).and_return([@tag1, @tag2])
      session[:tag_db] = "CloudVolume"
      edit = {
        :key        => "CloudVolume_edit_tags__#{@volume.id}",
        :tagging    => "CloudVolume",
        :object_ids => [@volume.id],
        :current    => {:assignments => []},
        :new        => {:assignments => [@tag1.id, @tag2.id]}
      }
      session[:edit] = edit
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "builds tagging screen" do
      post :button, :params => {:pressed => "cloud_volume_tag", :format => :js, :id => @volume.id}
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "cloud_volume/show/#{@volume.id}"}, 'placeholder']
      post :tagging_edit, :params => {:button => "cancel", :format => :js, :id => @volume.id}
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "cloud_volume/show/#{@volume.id}"}, 'placeholder']
      post :tagging_edit, :params => {:button => "save", :format => :js, :id => @volume.id}
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#create_backup" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack)
      @volume = FactoryGirl.create(:cloud_volume_openstack,
                                   :name                  => "cloud-volume-01",
                                   :ext_management_system => @ems)
      @backup = FactoryGirl.create(:cloud_volume_backup)
    end

    context "#create_backup" do
      let(:task_options) do
        {
          :action => "creating Cloud Volume Backup for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @volume.class.name,
          :method_name => "backup_create",
          :instance_id => @volume.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "ems_operations",
          :zone        => @ems.my_zone,
          :args        => [{:name => "backup_name"}]
        }
      end

      it "builds create backup screen" do
        post :button, :params => { :pressed => "cloud_volume_backup_create", :format => :js, :id => @volume.id }
        expect(assigns(:flash_array)).to be_nil
      end

      it "queues the create cloud backup action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :backup_create, :params => { :button => "create",
          :format => :js, :id => @volume.id, :backup_name => 'backup_name' }
      end
    end
  end

  describe "#restore_backup" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack)
      @volume = FactoryGirl.create(:cloud_volume_openstack,
                                   :name                  => "cloud-volume-01",
                                   :ext_management_system => @ems)
      @backup = FactoryGirl.create(:cloud_volume_backup)
    end

    context "#restore_backup" do
      let(:task_options) do
        {
          :action => "restoring Cloud Volume from Backup for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @volume.class.name,
          :method_name => "backup_restore",
          :instance_id => @volume.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => "ems_operations",
          :zone        => @ems.my_zone,
          :args        => [@backup.ems_ref]
        }
      end

      it "builds restore backup screen" do
        post :button, :params => { :pressed => "cloud_volume_backup_restore", :format => :js, :id => @volume.id }
        expect(assigns(:flash_array)).to be_nil
      end

      it "queues restore from a cloud backup action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :backup_restore, :params => { :button => "restore",
          :format => :js, :id => @volume.id, :backup_id => @backup.id }
      end
    end
  end
end
