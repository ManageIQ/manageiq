describe CloudResourceQuotaController do
  context "#tags_edit" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @quota = FactoryGirl.create(:cloud_resource_quota, :name => "cloud-resource-quota-01")
      user = FactoryGirl.create(:user, :userid => 'testuser')
      set_user_privileges user
      allow(@quota).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "D    epartment")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@quota).and_return([@tag1, @tag2])
      session[:tag_db] = "CloudResourceQuota"
      edit = {
        :key        => "CloudResourceQuota_edit_tags__#{@quota.id}",
        :tagging    => "CloudResourceQuota",
        :object_ids => [@quota.id],
        :current    => {:assignments => []},
        :new        => {:assignments => [@tag1.id, @tag2.id]}
      }
      session[:edit] = edit
      session[:referer] = request.env["HTTP_REFERER"] = "http://localhost"
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "builds tagging screen" do
      post :button, :pressed => "cloud_resource_quota_tag", :format => :js, :id => @quota.id
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "cloud_resource_quota/show/#{@quota.id}"}, 'placeholder']
      post :tagging_edit, :button => "cancel", :format => :js, :id => @quota.id
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "cloud_tenant/show/#{@quota.id}"}, 'placeholder']
      post :tagging_edit, :button => "save", :format => :js, :id => @quota.id
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end
end
