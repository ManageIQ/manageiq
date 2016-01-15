describe CloudObjectStoreContainerController do
  context "#tags_edit" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @container = FactoryGirl.create(:cloud_object_store_container, :name => "cloud-object-store-container-01")
      user = FactoryGirl.create(:user, :userid => 'testuser')
      set_user_privileges user
      allow(@container).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "D    epartment")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@container).and_return([@tag1, @tag2])
      session[:tag_db] = "CloudObjectStoreContainer"
      edit = {
        :key        => "CloudObjectStoreContainer_edit_tags__#{@container.id}",
        :tagging    => "CloudObjectStoreContainer",
        :object_ids => [@container.id],
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
      post :button, :pressed => "cloud_object_store_container_tag", :format => :js, :id => @container.id
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "cloud_object_store_container/show/#{@container.id}"}, 'placeholder']
      post :tagging_edit, :button => "cancel", :format => :js, :id => @container.id
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "cloud_object_store_container/show/#{@container.id}"}, 'placeholder']
      post :tagging_edit, :button => "save", :format => :js, :id => @container.id
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end
end
