describe CloudVolumeBackupController do
  context "#tags_edit" do
    let!(:user) { stub_user(:features => :all) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @backup = FactoryGirl.create(:cloud_volume_backup, :name => "cloud-volume-backup-01")
      allow(@backup).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "D    epartment")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@backup).and_return([@tag1, @tag2])
      session[:tag_db] = "CloudVolumeBackup"
      edit = {
        :key        => "CloudVolumeBackup_edit_tags__#{@backup.id}",
        :tagging    => "CloudVolumeBackup",
        :object_ids => [@backup.id],
        :current    => {:assignments => []},
        :new        => {:assignments => [@tag1.id, @tag2.id]}
      }
      session[:edit] = edit
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "builds tagging screen" do
      post :button, :params => {:pressed => "cloud_volume_backup_tag", :format => :js, :id => @backup.id}
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "cloud_volume_backup/show/#{@backup.id}"}, 'placeholder']
      post :tagging_edit, :params => {:button => "cancel", :format => :js, :id => @backup.id}
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "cloud_volume_backup/show/#{@backup.id}"}, 'placeholder']
      post :tagging_edit, :params => {:button => "save", :format => :js, :id => @backup.id}
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end
end
