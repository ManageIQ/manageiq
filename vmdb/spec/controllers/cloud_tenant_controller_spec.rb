require "spec_helper"

describe CloudTenantController do
  context "#button" do
    before(:each) do
      set_user_privileges
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
    end

    it "when Instance Retire button is pressed" do
      controller.should_receive(:retirevms).once
      post :button, :pressed => "instance_retire", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end

    it "when Instance Tag is pressed" do
      controller.should_receive(:tag).with(VmOrTemplate)
      post :button, :pressed => "instance_tag", :format => :js
      controller.send(:flash_errors?).should_not be_true
    end
  end

  context "#tags_edit" do
    before(:each) do
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
      @ct = FactoryGirl.create(:cloud_tenant, :name => "cloud-tenant-01")
      user = FactoryGirl.create(:user, :userid => 'testuser')
      set_user_privileges user
      @ct.stub(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "D    epartment")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      Classification.stub(:find_assigned_entries).with(@ct).and_return([@tag1, @tag2])
      session[:tag_db] = "CloudTenant"
      edit = {
        :key        => "CloudTenant_edit_tags__#{@ct.id}",
        :tagging    => "CloudTenant",
        :object_ids => [@ct.id],
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
      post :button, :pressed => "cloud_tenant_tag", :format => :js, :id => @ct.id
      assigns(:flash_array).should be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "cloud_tenant/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :button => "cancel", :format => :js, :id => @ct.id
      assigns(:flash_array).first[:message].should include("was cancelled by the user")
      assigns(:edit).should be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "cloud_tenant/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :button => "save", :format => :js, :id => @ct.id
      assigns(:flash_array).first[:message].should include("Tag edits were successfully saved")
      assigns(:edit).should be_nil
    end
  end
end
