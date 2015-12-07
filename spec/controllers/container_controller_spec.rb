require "spec_helper"

describe ContainerController do
  before(:each) do
    server = EvmSpecHelper.local_miq_server
    MiqServer.stub(:my_server).and_return(server)
    MiqServer.stub(:my_zone).and_return("default")
    session[:settings] = {:views => {}}
    set_user_privileges
  end

  render_views

  context "#tags_edit" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ct = FactoryGirl.create(:container, :name => "container-01")
      user = FactoryGirl.create(:user, :userid => 'testuser')
      set_user_privileges user
      @ct.stub(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      sandbox = {:active_tree => :containers_tree, :trees => {:containers_tree => {:active_node => "cnt_#{controller.to_cid(@ct.id)}"}}}
      controller.instance_variable_set(:@sb, sandbox)

      controller.x_active_tree = 'containers_tree'
      controller.stub(:x_node).and_return("cnt_#{controller.to_cid(@ct.id)}")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      Classification.stub(:find_assigned_entries).with(@ct).and_return([@tag1, @tag2])
      controller.instance_variable_set(:@sb,
                                       :trees       => {:containers_tree => {:active_node => "root"}},
                                       :active_tree => :containers_tree)
      controller.stub(:get_node_info)
      session[:tag_db] = "Container"
      edit = {
        :key        => "Container_edit_tags__#{@ct.id}",
        :tagging    => "Container",
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
      post :x_button, :pressed => "container_tag", :format => :js, :id => @ct.id
      assigns(:flash_array).should be_nil
      assigns(:entries).should_not be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "container/explorer}"}, 'placeholder']
      post :container_tag, :button => "cancel", :id => @ct.id
      assigns(:flash_array).first[:message].should include("was cancelled")
      assigns(:edit).should be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "container/explorer"}, 'placeholder']
      post :container_tag, :button => "save", :format => :js, :id => @ct.id
      assigns(:flash_array).first[:message].should include("Tag edits were successfully saved")
      assigns(:edit).should be_nil
    end
  end
end
