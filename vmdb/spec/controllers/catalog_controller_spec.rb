require "spec_helper"

describe CatalogController do
  before(:each) do
    set_user_privileges
  end

  # some methods should not be accessible through the legacy routes
  # either by being private or through the hide_action mechanism
  it 'should not allow call of hidden/private actions' do
    expect {
      post :process_sts
    }.to raise_error AbstractController::ActionNotFound
  end

  describe 'x_button' do
    describe 'corresponding methods are called for allowed actions' do
      CatalogController::CATALOG_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, actual_method|
        it "calls the appropriate method: '#{actual_method}' for action '#{action_name}'" do
          controller.should_receive(actual_method)
          get :x_button, :pressed => action_name
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :pressed => 'random_dude', :format => :html
      expect { response }.to render_template('layouts/exception')
    end
  end

  context "#atomic_st_edit" do
    it "Atomic Service Template and it's Resource Actions are saved" do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, {:button => "save"})
      st = FactoryGirl.create(:service_template)
      retire_fqname = "ns/cls/inst"
      provision_fqname = "ns1/cls1/inst1"
      recon_fqname = "ns2/cls2/inst2"
      edit = {
        :new          => {
          :name               => "New Name",
          :description        => "New Description",
          :reconfigure_fqname => recon_fqname,
          :retire_fqname      => retire_fqname,
          :fqname             => provision_fqname},
        :key          => "prov_edit__new",
        :rec_id       => st.id,
        :st_prov_type => "generic"
      }
      controller.instance_variable_set(:@edit, edit)
      session[:edit] = edit
      controller.stub(:replace_right_cell)
      controller.send(:atomic_st_edit)
      {'Provision' => provision_fqname, 'Reconfigure' => recon_fqname, 'Retirement' => retire_fqname}.each do |k, v|
        st.resource_actions.find_by_action(k).fqname.should == "/#{v}"
      end
    end
  end

  context "#st_edit" do
    it "@record is cleared out after Service Template is added" do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, {:button => "add"})
      st = FactoryGirl.create(:service_template)
      controller.instance_variable_set(:@record, st)
      edit = {
          :new => {:name => "New Name", :description => "New Description", :selected_resources => [st.id], :rsc_groups => [[{:name => "Some name"}]]},
          :key => "st_edit__new",
          :rec_id => st.id,
      }
      controller.instance_variable_set(:@edit, edit)
      session[:edit] = edit
      controller.stub(:replace_right_cell)
      controller.send(:st_edit)
      assigns(:record).should == nil
    end
  end

  context "#ot_edit" do
    before(:each) do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, :button => "save")
      controller.should_receive(:render)
      @new_name = "New Name"
      @new_description = "New Description"
      @new_content = "New Content\n"
      session[:edit] = {
        :new    => {
          :name        => @new_name,
          :description => @new_description},
      }
    end

    after(:each) do
      expect(response.status).to eq(200)
      assigns(:edit).should be_nil
    end

    it "Orchestration Template name and description are edited" do
      ot = FactoryGirl.create(:orchestration_template)
      controller.instance_variable_set(:@record, ot)
      controller.params.merge!(:id => ot.id, :template_content => @new_content)
      session[:edit][:key] = "ot_edit__#{ot.id}"
      session[:edit][:rec_id] = ot.id
      controller.stub(:replace_right_cell)
      controller.send(:ot_edit_submit)
      controller.send(:flash_errors?).should_not be_true
      assigns(:flash_array).first[:message].should include("was saved")
      ot.reload
      ot.name.should == @new_name
      ot.description.should == @new_description
      ot.content.should == @new_content
    end

    it "Read-only Orchestration Template content cannot be edited" do
      ot = FactoryGirl.create(:orchestration_template_with_stacks)
      original_content = ot.content
      controller.params.merge!(:id => ot.id, :template_content => @new_content)
      session[:edit][:key] = "ot_edit__#{ot.id}"
      session[:edit][:rec_id] = ot.id
      controller.stub(:replace_right_cell)
      controller.send(:ot_edit_submit)
      ot.reload
      ot.content.should == original_content
    end
  end

  context "#ot_copy" do
    it "Orchestration Template is copied" do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, :button => "save")
      controller.should_receive(:render)
      ot = FactoryGirl.create(:orchestration_template)
      controller.x_node = "xx-ot_othot-#{ot.id}"
      new_name = "New Name"
      new_description = "New Description"
      new_content = "New Content"
      controller.params.merge!(:id               => ot.id,
                               :name             => new_name,
                               :description      => new_description,
                               :template_content => new_content)
      controller.stub(:replace_right_cell)
      controller.send(:ot_copy_submit)
      controller.send(:flash_errors?).should_not be_true
      assigns(:flash_array).first[:message].should include("was saved")
      expect(response.status).to eq(200)
      OrchestrationTemplate.find_by_name(new_name).should_not be_nil
    end
  end

  context "#ot_delete" do
    before(:each) do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, :pressed => "orchestration_template_remove")
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "Orchestration Template is deleted" do
      ot = FactoryGirl.create(:orchestration_template)
      controller.instance_variable_set(:@_response, ActionController::TestResponse.new)
      controller.params.merge!(:id => ot.id)
      controller.stub(:replace_right_cell)
      controller.send(:ot_remove_submit)
      controller.send(:flash_errors?).should_not be_true
      assigns(:flash_array).first[:message].should include("was deleted")
      OrchestrationTemplate.find_by_id(ot.id).should be_nil
    end

    it "Read-only Orchestration Template cannot deleted" do
      ot = FactoryGirl.create(:orchestration_template_with_stacks)
      controller.params.merge!(:id => ot.id)
      controller.should_receive(:render)
      controller.stub(:replace_right_cell)
      controller.send(:ot_remove_submit)
      controller.send(:flash_errors?).should be_true
      assigns(:flash_array).first[:message].should include("read-only and cannot be deleted")
      OrchestrationTemplate.find_by_id(ot.id).should_not be_nil
    end
  end

  context "#ot_create" do
    before(:each) do
      @new_name = "New Name"
      new_description = "New Description"
      new_type = "OrchestrationTemplateCfn"
      @new_content = "New Content"
      edit = {
        :new => {
          :name        => @new_name,
          :description => new_description,
          :content     => @new_content,
          :type        => new_type,
          :draft       => false},
        :key => "ot_add__new",
      }
      session[:edit] = edit
      controller.instance_variable_set(:@sb, :trees => {:ot_tree => {:open_nodes => []}}, :active_tree => :ot_tree)
    end

    it "Orchestration Template is created" do
      controller.instance_variable_set(:@_params, :content => @new_content, :button => "add")
      controller.should_receive(:render)
      controller.stub(:replace_right_cell)
      controller.send(:ot_add_submit)
      controller.send(:flash_errors?).should_not be_true
      assigns(:flash_array).first[:message].should include("was saved")
      assigns(:edit).should be_nil
      expect(response.status).to eq(200)
      OrchestrationTemplate.find_by_name(@new_name).should_not be_nil
    end

    it "Orchestration Template draft is created" do
      controller.instance_variable_set(:@_params, :content => @new_content, :button => "add")
      session[:edit][:new][:draft] = true
      controller.should_receive(:render)
      controller.stub(:replace_right_cell)
      controller.send(:ot_add_submit)
      controller.send(:flash_errors?).should_not be_true
      assigns(:flash_array).first[:message].should include("was saved")
      assigns(:edit).should be_nil
      expect(response.status).to eq(200)
      ot = OrchestrationTemplate.find_by_name(@new_name)
      ot.should_not be_nil
      ot.draft.should be_true
    end

    it "Orchestration Template creation is cancelled" do
      controller.instance_variable_set(:@_params, :content => @new_content, :button => "cancel")
      controller.stub(:replace_right_cell)
      controller.send(:ot_add_submit)
      controller.send(:flash_errors?).should_not be_true
      assigns(:flash_array).first[:message].should include("was cancelled")
      assigns(:edit).should be_nil
      expect(response.status).to eq(200)
      OrchestrationTemplate.find_by_name(@new_name).should be_nil
    end
  end
end
