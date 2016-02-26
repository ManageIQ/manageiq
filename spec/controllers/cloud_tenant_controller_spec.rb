describe CloudTenantController do
  context "#button" do
    before(:each) do
      set_user_privileges
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
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ct = FactoryGirl.create(:cloud_tenant, :name => "cloud-tenant-01")
      user = FactoryGirl.create(:user, :userid => 'testuser')
      set_user_privileges user
      allow(@ct).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "D    epartment")
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
      session[:referer] = request.env["HTTP_REFERER"] = "http://localhost"
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
      @user = FactoryGirl.create(:user)
      login_as @user
    end

    subject do
      get :show, :id => @tenant.id
    end

    context "render listnav partial" do
      render_views
      it { is_expected.to have_http_status 200 }
      it { is_expected.to render_template(:partial => "layouts/listnav/_cloud_tenant") }
    end
  end
end
