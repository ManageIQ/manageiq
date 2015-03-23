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
    it "Atomic Service Template and it's valid Resource Actions are saved" do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, {:button => "save"})
      st = FactoryGirl.create(:service_template)
      3.times.each_with_index do |i|
        ns = FactoryGirl.create(:miq_ae_namespace, :name => "ns#{i}")
        cls = FactoryGirl.create(:miq_ae_class, :namespace_id => ns.id, :name => "cls#{i}")
        FactoryGirl.create(:miq_ae_instance, :class_id => cls.id, :name => "inst#{i}")
      end
      retire_fqname    = 'ns0/cls0/inst0'
      provision_fqname = 'ns1/cls1/inst1'
      recon_fqname     = 'ns2/cls2/inst2'
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

    it "Atomic Service Template and it's invalid Resource Actions are not saved" do
      controller.instance_variable_set(:@_response, ActionController::TestResponse.new)
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, :button => 'save')
      st = FactoryGirl.create(:service_template)
      retire_fqname    = 'ns/cls/inst'
      provision_fqname = 'ns1/cls1/inst1'
      recon_fqname     = 'ns2/cls2/inst2'
      edit = {
        :new          => {
          :name               => 'New Name',
          :description        => 'New Description',
          :reconfigure_fqname => recon_fqname,
          :retire_fqname      => retire_fqname,
          :fqname             => provision_fqname},
        :key          => 'prov_edit__new',
        :rec_id       => st.id,
        :st_prov_type => 'generic'
      }
      controller.instance_variable_set(:@edit, edit)
      session[:edit] = edit
      controller.stub(:replace_right_cell)
      controller.send(:atomic_st_edit)
      controller.send(:flash_errors?).should be_true
      flash_messages = assigns(:flash_array)
      expect(flash_messages).to have_exactly(3).items
      entry_point_names = %w(Provisioning Reconfigure Retirement)
      flash_messages.each_with_index do |msg, i|
        expect(msg[:message]).to eq("Please correct invalid #{entry_point_names[i]} Entry Point prior to saving")
        expect(msg[:level]).to eq(:error)
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
      @new_content = "{\"AWSTemplateFormatVersion\" : \"new-version\"}\n"
      session[:edit] = {
        :new    => {
          :name        => @new_name,
          :description => @new_description},
      }
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "Orchestration Template name and description are edited" do
      ot = FactoryGirl.create(:orchestration_template_cfn)
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
      expect(response.status).to eq(200)
      assigns(:edit).should be_nil
    end

    it "Read-only Orchestration Template content cannot be edited" do
      ot = FactoryGirl.create(:orchestration_template_cfn_with_stacks)
      original_content = ot.content
      controller.params.merge!(:id => ot.id, :template_content => @new_content)
      session[:edit][:key] = "ot_edit__#{ot.id}"
      session[:edit][:rec_id] = ot.id
      controller.stub(:replace_right_cell)
      controller.send(:ot_edit_submit)
      ot.reload
      ot.content.should == original_content
      expect(response.status).to eq(200)
      assigns(:edit).should be_nil
    end

    it "Orchestration Template content cannot be empty during edit" do
      controller.instance_variable_set(:@_params, :button => "save")
      controller.instance_variable_set(:@_response, ActionController::TestResponse.new)
      ot = FactoryGirl.create(:orchestration_template)
      session[:edit][:key] = "ot_edit__#{ot.id}"
      session[:edit][:rec_id] = ot.id
      original_content = ot.content
      new_content = ""
      controller.params.merge!(:id => ot.id, :template_content => new_content)
      controller.stub(:replace_right_cell)
      controller.send(:ot_edit_submit)
      controller.send(:flash_errors?).should be_true
      assigns(:flash_array).first[:message].should include("cannot be empty")
      ot.reload
      ot.content.should == original_content
    end

    it "Draft flag is set for an Orchestration Template" do
      ot = FactoryGirl.create(:orchestration_template)
      controller.params.merge!(:id => ot.id, :template_content => @new_content)
      session[:edit][:key] = "ot_edit__#{ot.id}"
      session[:edit][:rec_id] = ot.id
      session[:edit][:new][:draft] = "true"
      controller.stub(:replace_right_cell)
      controller.send(:ot_edit_submit)
      ot.reload
      ot.draft.should be_true
      assigns(:edit).should be_nil
    end
  end

  context "#ot_copy" do
    before(:each) do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, :button => "save")
      controller.should_receive(:render)
      ot = FactoryGirl.create(:orchestration_template_cfn)
      controller.x_node = "xx-ot_othot-#{ot.id}"
      @new_name = "New Name"
      new_description = "New Description"
      new_content = "{\"AWSTemplateFormatVersion\" : \"new-version\"}"
      controller.params.merge!(:id               => ot.id,
                               :name             => @new_name,
                               :description      => new_description,
                               :template_content => new_content)
    end

    after(:each) do
      controller.send(:flash_errors?).should_not be_true
      assigns(:flash_array).first[:message].should include("was saved")
      expect(response.status).to eq(200)
      OrchestrationTemplate.where(:name => @new_name).first.should_not be_nil
    end

    it "Orchestration Template is copied" do
      controller.stub(:replace_right_cell)
      controller.send(:ot_copy_submit)
    end

    it "Orchestration Template is copied as a draft" do
      controller.params.merge!(:draft => "true")
      controller.stub(:replace_right_cell)
      controller.send(:ot_copy_submit)
      OrchestrationTemplate.where(:name => @new_name).first.draft.should be_true
    end
  end

  context "#ot_delete" do
    before(:each) do
      controller.instance_variable_set(:@sb, {})
      controller.instance_variable_set(:@_params, :pressed => "orchestration_template_remove")
      controller.stub(:replace_right_cell)
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "Orchestration Template is deleted" do
      ot = FactoryGirl.create(:orchestration_template)
      controller.instance_variable_set(:@_response, ActionController::TestResponse.new)
      controller.params.merge!(:id => ot.id)
      controller.send(:ot_remove_submit)
      controller.send(:flash_errors?).should_not be_true
      assigns(:flash_array).first[:message].should include("was deleted")
      OrchestrationTemplate.find_by_id(ot.id).should be_nil
    end

    it "Read-only Orchestration Template cannot deleted" do
      ot = FactoryGirl.create(:orchestration_template_with_stacks)
      controller.params.merge!(:id => ot.id)
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
      @new_content = '{"AWSTemplateFormatVersion" : "2010-09-09"}'
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
      OrchestrationTemplate.where(:name => @new_name).first.should_not be_nil
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
      ot = OrchestrationTemplate.where(:name => @new_name).first
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
      OrchestrationTemplate.where(:name => @new_name).first.should be_nil
    end
  end

  describe "#tags_edit" do
    before(:each) do
      @ot = FactoryGirl.create(:orchestration_template, :name => "foo")
      user = FactoryGirl.create(:user, :userid => 'testuser')
      session[:userid] = user.userid
      @ot.stub(:tagged_with).with(:cat => "testuser").and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification
      )
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification
      )
      Classification.stub(:find_assigned_entries).with(@ot).and_return([@tag1, @tag2])
      controller.instance_variable_set(:@sb,
                                       :trees       => {:ot_tree => {:active_node => "root"}},
                                       :active_tree => :ot_tree)
      controller.stub(:get_node_info)
      controller.stub(:replace_right_cell)
      session[:tag_db] = "OrchestrationTemplate"
      edit = {
        :key        => "OrchestrationTemplate_edit_tags__#{@ot.id}",
        :tagging    => "OrchestrationTemplate",
        :object_ids => [@ot.id],
        :current    => {:assignments => []},
        :new        => {:assignments => [@tag1.id, @tag2.id]}
      }
      session[:edit] = edit
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "builds tagging screen" do
      controller.instance_variable_set(:@sb, :action => "ot_tags_edit")
      controller.instance_variable_set(:@_params, :miq_grid_checks => @ot.id.to_s)
      controller.send(:tags_edit, "OrchestrationTemplate")
      assigns(:flash_array).should be_nil
      assigns(:entries).should_not be_nil
    end

    it "cancels tags edit" do
      controller.instance_variable_set(:@_params, :button => "cancel", :id => @ot.id)
      controller.send(:tags_edit, "OrchestrationTemplate")
      assigns(:flash_array).first[:message].should include("was cancelled")
      assigns(:edit).should be_nil
    end

    it "save tags" do
      controller.instance_variable_set(:@_params, :button => "save", :id => @ot.id)
      controller.send(:tags_edit, "OrchestrationTemplate")
      assigns(:flash_array).first[:message].should include("Tag edits were successfully saved")
      assigns(:edit).should be_nil
    end
  end

  context "#service_dialog_create_from_ot" do
    before(:each) do
      @ot = FactoryGirl.create(:orchestration_template_cfn_with_content)
      @dialog_label = "New Dialog 01"
      session[:edit] = {
        :new    => {:dialog_name => @dialog_label},
        :key    => "ot_edit__#{@ot.id}",
        :rec_id => @ot.id
      }
      controller.instance_variable_set(:@sb, :trees => {:ot_tree => {:open_nodes => []}}, :active_tree => :ot_tree)
      controller.instance_variable_set(:@_response, ActionController::TestResponse.new)
    end

    after(:each) do
      controller.send(:flash_errors?).should_not be_true
      assigns(:edit).should be_nil
      expect(response.status).to eq(200)
    end

    it "Service Dialog is created from an Orchestration Template" do
      controller.instance_variable_set(:@_params, :button => "save", :id => @ot.id)
      controller.stub(:replace_right_cell)
      controller.send(:service_dialog_from_ot_submit)
      assigns(:flash_array).first[:message].should include("was successfully created")
      Dialog.where(:label => @dialog_label).first.should_not be_nil
    end
  end

  context "#ot_rendering" do
    render_views
    before(:each) do
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone
      expect(MiqServer.my_guid).to be
      expect(MiqServer.my_server).to be
      session[:userid] = User.current_user.userid
      session[:settings] = {
        :views => {:orchestrationtemplate => "grid"}
      }
      session[:sandboxes] = {
        "catalog" => {
          :active_tree => :ot_tree
        }
      }

      FactoryGirl.create(:orchestration_template_cfn_with_content)
      FactoryGirl.create(:orchestration_template_hot_with_content)
    end

    after(:each) do
      controller.send(:flash_errors?).should_not be_true
      expect(response.status).to eq(200)
    end

    it "Renders list of orchestration templates using correct GTL type" do
      %w(root xx-otcfn xx-othot).each do |id|
        post :tree_select, :id => id, :format => :js
        response.should render_template('layouts/gtl/_grid')
      end
    end
  end
end
