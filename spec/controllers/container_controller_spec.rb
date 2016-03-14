describe ContainerController do
  before(:each) do
    server = EvmSpecHelper.local_miq_server
    allow(MiqServer).to receive(:my_server).and_return(server)
    allow(MiqServer).to receive(:my_zone).and_return("default")
    set_user_privileges
  end

  render_views

  context "#tags_edit" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ct = FactoryGirl.create(:container, :name => "container-01")
      user = FactoryGirl.create(:user, :userid => 'testuser')
      set_user_privileges user
      allow(@ct).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      sandbox = {:active_tree => :containers_tree, :trees => {:containers_tree => {:active_node => "cnt_#{controller.to_cid(@ct.id)}"}}}
      controller.instance_variable_set(:@sb, sandbox)

      controller.x_active_tree = 'containers_tree'
      allow(controller).to receive(:x_node).and_return("cnt_#{controller.to_cid(@ct.id)}")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@ct).and_return([@tag1, @tag2])
      controller.instance_variable_set(:@sb,
                                       :trees       => {:containers_tree => {:active_node => "root"}},
                                       :active_tree => :containers_tree)
      allow(controller).to receive(:get_node_info)
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
      post :x_button, :params => { :pressed => "container_tag", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array)).to be_nil
      expect(assigns(:entries)).not_to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "container/explorer}"}, 'placeholder']
      post :container_tag, :params => { :button => "cancel", :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("was cancelled")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "container/explorer"}, 'placeholder']
      post :container_tag, :params => { :button => "save", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end

  context "#x_button" do
    before(:each) do
      ems = FactoryGirl.create(:ems_kubernetes)
      container_project = ContainerProject.create(:ext_management_system => ems)
      container_group = ContainerGroup.create(:ext_management_system => ems,
                                              :container_project     => container_project)
      @ct = FactoryGirl.create(:container,
                               :name            => "container-01",
                               :container_group => container_group
                              )
      allow(controller).to receive(:x_node).and_return("cnt_#{controller.to_cid(@ct.id)}")
      controller.instance_variable_set(:@record, @ct)
      FactoryGirl.create(:ems_event, :container_id => @ct.id)
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "renders timeline views" do
      post :x_button, :params => {
        :pressed => "container_timeline",
        :id      => @ct.id,
        :display => 'timeline'
      }
      expect(response).to render_template('layouts/_tl_show')
      expect(response).to render_template('layouts/_tl_detail')
    end

    it "renders utilization views" do
      post :x_button, :params => {
        :pressed => "container_perf",
        :id      => @ct.id,
        :display => 'performance'
      }
      expect(response).to render_template('layouts/_perf_options')
      expect(response).to render_template('layouts/_perf_charts')
    end
  end
end
