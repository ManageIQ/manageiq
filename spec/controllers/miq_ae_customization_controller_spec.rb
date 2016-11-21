describe MiqAeCustomizationController do
  before(:each) do
    stub_user(:features => :all)
  end

  context "#get_node_info" do
    it "Don't need to validate active node when editing Dialogs" do
      controller.instance_variable_set(:@sb, :trees => {:dialog_edit_tree => {:active_node => "root"}}, :active_tree => :dialog_edit_tree)
      expect(controller).not_to receive(:valid_active_node)
      expect(controller).to receive(:dialog_edit_set_form_vars)
      controller.send(:get_node_info)
    end
  end

  describe "group_reorder_field_changed" do
    before(:each) do
      allow(controller).to receive(:load_edit).and_return(true)
      controller.instance_variable_set(:@edit, :new => {:fields => [['test', 100], ['test1', 101], ['test2', 102], ['test3', 103]]})
    end

    context "#move_cols_up" do
      it "move one button up" do
        post :group_reorder_field_changed, :params => { :id => 'seq', :button => 'up', 'selected_fields' => ['101'] }
        expect(controller.instance_variable_get(:@edit)).to eql(:new => {:fields => [['test1', 101], ['test', 100], ['test2', 102], ['test3', 103]]})
      end

      it "move 2 button up" do
        post :group_reorder_field_changed, :params => { :id => 'seq', :button => 'up', 'selected_fields' => ['101', '102'] }
        expect(controller.instance_variable_get(:@edit)).to eql(:new => {:fields => [['test1', 101], ['test2', 102], ['test', 100], ['test3', 103]]})
      end
    end

    context "#move_cols_down" do
      it "move one button down" do
        post :group_reorder_field_changed, :params => { :id => 'seq', :button => 'down', 'selected_fields' => ['101'] }
        expect(controller.instance_variable_get(:@edit)).to eql(:new => {:fields => [['test', 100], ['test2', 102], ['test1', 101], ['test3', 103]]})
      end

      it "move 2 buttons down" do
        post :group_reorder_field_changed, :params => { :id => 'seq', :button => 'down', 'selected_fields' => ['101', '102'] }
        expect(controller.instance_variable_get(:@edit)).to eql(:new => {:fields => [['test', 100], ['test3', 103], ['test1', 101], ['test2', 102]]})
      end
    end

    context "no button selected" do
      it "moves up and display error message" do
        post :group_reorder_field_changed, :params => { :id => 'seq', :button => 'up' }
        expect(response.body).to include("flash")
      end

      it "moves down and display error message" do
        post :group_reorder_field_changed, :params => { :id => 'seq', :button => 'down' }
        expect(response.body).to include("flash")
      end
    end
  end

  describe "#group_form_field_changed" do
    before(:each) do
      allow(controller).to receive(:load_edit).and_return(true)
      controller.instance_variable_set(:@edit, :new => {:fields => [['value', 100], ['value1', 101], ['value2', 102], ['value3', 103]]})
    end

    context "assign buttons" do
      it "moves button up" do
        post :group_form_field_changed, :params => { 'selected_fields' => ['101'], :button => 'up' }
        expect(controller.instance_variable_get(:@edit)).to eql(:new => {:fields => [['value1', 101], ['value', 100], ['value2', 102], ['value3', 103]]})
      end

      it "moves button down" do
        post :group_form_field_changed, :params => { 'selected_fields' => ['101'], :button => 'down' }
        expect(controller.instance_variable_get(:@edit)).to eql(:new => {:fields => [['value', 100], ['value2', 102], ['value1', 101], ['value3', 103]]})
      end

      it "moves button to the top" do
        post :group_form_field_changed, :params => { 'selected_fields' => ['101'], :button => 'top' }
        expect(controller.instance_variable_get(:@edit)).to eql(:new => {:fields => [['value1', 101], ['value', 100], ['value2', 102], ['value3', 103]]})
      end

      it "moves button to the bottom" do
        post :group_form_field_changed, :params => { 'selected_fields' => ['101'], :button => 'bottom' }
        expect(controller.instance_variable_get(:@edit)).to eql(:new => {:fields => [['value', 100], ['value2', 102], ['value3', 103], ['value1', 101]]})
      end

      context "no selected button" do
        it "moves up and display error message" do
          post :group_form_field_changed, :params => { :button => 'up' }
          expect(response.body).to include("flash")
        end

        it "moves down and display error message" do
          post :group_form_field_changed, :params => { :button => 'down' }
          expect(response.body).to include("flash")
        end

        it "moves up and display error message" do
          post :group_form_field_changed, :params => { :button => 'top' }
          expect(response.body).to include("flash")
        end

        it "moves down and display error message" do
          post :group_form_field_changed, :params => { :button => 'bottom' }
          expect(response.body).to include("flash")
        end
      end

      context "all buttons selected" do
        it "moves to the top and nothing happen" do
          post :group_form_field_changed, :params => { :button => 'top', 'selected_fields' => ['100', '101', '102', '103'] }
          expect(controller.instance_variable_get(:@edit)).to eql(:new => {:fields => [['value', 100], ['value1', 101], ['value2', 102], ['value3', 103]]})
        end

        it "moves to the bottom and nothing happen" do
          post :group_form_field_changed, :params => { :button => 'bottom', 'selected_fields' => ['100', '101', '102', '103'] }
          expect(controller.instance_variable_get(:@edit)).to eql(:new => {:fields => [['value', 100], ['value1', 101], ['value2', 102], ['value3', 103]]})
        end
      end
    end
  end

  describe 'x_button' do
    before(:each) do
      ApplicationController.handle_exceptions = true
    end

    describe 'corresponding methods are called for allowed actions' do
      MiqAeCustomizationController::AE_CUSTOM_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        it "calls the appropriate method: '#{method}' for action '#{action_name}'" do
          expect(controller).to receive(method)
          get :x_button, :params => { :pressed => action_name }
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :params => { :pressed => 'random_dude', :format => :html }
      expect(response).to render_template('layouts/exception')
    end
  end

  describe "#explorer" do
    #include_context "valid session"

    let(:sandbox_flash_messages) { nil }

    before do
      session[:settings] =  {:display => {:locale => 'default'}}
      controller.instance_variable_set(:@settings, :display => {:locale => 'default'})
      controller.instance_variable_set(:@sb, :flash_msg => sandbox_flash_messages)
      bypass_rescue
    end

    it "assigns the sandbox active tree" do
      login_as FactoryGirl.create(:user, :features => "old_dialogs_accord")
      get :explorer
      expect(assigns(:sb)[:active_tree]).to eq(:old_dialogs_tree)
    end

    it "assigns the sandbox active accord" do
      login_as FactoryGirl.create(:user, :features => "old_dialogs_accord")
      get :explorer
      expect(assigns(:sb)[:active_accord]).to eq(:old_dialogs)
    end

    it "assigns the sandbox active node on old dialogs tree to root" do
      login_as FactoryGirl.create(:user, :features => "old_dialogs_accord")
      get :explorer
      expect(controller.x_node).to eq("root")
    end

    it "builds the old dialogs tree" do
      login_as FactoryGirl.create(:user, :features => "old_dialogs_accord")
      get :explorer
      expect(assigns(:sb)[:trees]).to include(:old_dialogs_tree)
    end

    it "assigns the sandbox active node on dialogs tree to root" do
      login_as FactoryGirl.create(:user, :features => "dialog_accord")
      get :explorer
      expect(controller.x_node).to eq("root")
    end

    it "builds the dialog tree" do
      login_as FactoryGirl.create(:user, :features => "dialog_accord")
      get :explorer
      expect(assigns(:sb)[:trees]).to include(:dialogs_tree)
    end

    it "assigns the sandbox active node on ab tree to root" do
      login_as FactoryGirl.create(:user, :features => "dialog_accord")
      get :explorer
      expect(expect(controller.x_node).to eq("root"))
    end

    it "builds the ab tree" do
      login_as FactoryGirl.create(:user, :features => "ab_buttons_accord")
      allow(controller).to receive(:get_node_info)
      get :explorer
      expect(assigns(:sb)[:trees]).to include(:ab_tree)
    end

    it "assigns the sandbox active node on import/export tree to root" do
      login_as FactoryGirl.create(:user, :features => "miq_ae_class_import_export")
      get :explorer
      expect(expect(controller.x_node).to eq("root"))
    end

    it "builds the import/export tree" do
      login_as FactoryGirl.create(:user, :features => "miq_ae_class_import_export")
      get :explorer
      expect(assigns(:sb)[:trees]).to include(:dialog_import_export_tree)
    end

    context "when the sandbox has flash messages" do
      let(:sandbox_flash_messages) { ["the flash messages"] }

      before do
        allow(controller).to receive(:get_global_session_data)
      end

      it "includes the flash messages from the sandbox" do
        get :explorer
        expect(assigns(:flash_array)).to include("the flash messages")
      end
    end

    context "when the sandbox does not have flash messages" do
      it "does not include the flash message from the sandbox" do
        get :explorer
        expect(assigns(:flash_array)).not_to include("the flash messages")
      end
    end

    context "when in dialog edit state" do
      render_views

      before do
        FactoryGirl.create(:miq_server, :guid => MiqServer.my_guid)
        MiqServer.my_server_clear_cache

        # It looks like edit state causes some of the features to be denied
        # Why?
        stub_user(:features => :none)
      end

      it "still renders the main_div" do
        session[:sandboxes] = {
          "miq_ae_customization" => {
            :trees         => {:dialog_edit_tree => {:active_node => "root"},
                               :dialogs_tree     => {:active_node => "root"}},
            :active_tree   => :dialog_edit_tree,
            :active_accord => :dialogs,
          },
        }
        session[:edit] = {
          :new => {},
          :current => {},
        }

        get :explorer

        expect(assigns(:sb)[:active_tree]).to eq(:dialogs_tree)
        expect(response).to render_template('miq_ae_customization/explorer')

        # empty main_div
        expect(response.body).not_to match(/<div id=['"]main_div['"]>\s*<\/div>/)
      end
    end
  end

  describe "#upload_import_file" do
    include_context "valid session"

    let(:dialog_import_service) { double("DialogImportService") }

    before do
      bypass_rescue
      allow(controller).to receive(:get_node_info)
      controller.instance_variable_set(:@sb,
                                       :trees       => {:dialog_import_export_tree => {:active_node => "root"}},
                                       :active_tree => :dialog_import_export_tree)
    end

    shared_examples_for "MiqAeCustomizationController#upload_import_file that does not upload a file" do
      it "redirects with a warning message" do
        post :upload_import_file, :params => params, :xhr => true
        expect(controller.instance_variable_get(:@flash_array))
          .to include(:message => "Use the Choose file button to locate an import file", :level => :warning)
      end
    end

    context "when an upload file is given" do
      let(:import_file_upload) { double("ImportFileUpload") }
      let(:filename) { "filename" }
      let(:file) { fixture_file_upload("files/dummy_file.yml", "text/yml") }
      let(:params) { {:upload => {:file => file}} }

      before do
        allow(DialogImportService).to receive(:new).and_return(dialog_import_service)
        allow(import_file_upload).to receive(:id).and_return(123)
        allow(import_file_upload).to receive(:service_dialog_list)
      end

      context "when the dialog importer does not raise an error" do
        before do
          allow(dialog_import_service).to receive(:store_for_import).with("the yaml data\n").and_return(import_file_upload)
        end

        it "redirects to review_import with a message to select a Dialog" do
          post :upload_import_file, :params => params, :xhr => true
          expect(controller.instance_variable_get(:@flash_array))
            .to include(:message => "Select Dialogs to import", :level => :info)
        end

        it "imports the dialogs" do
          expect(dialog_import_service).to receive(:store_for_import).with("the yaml data\n")
          post :upload_import_file, :params => params, :xhr => true
        end
      end

      context "when the dialog importer raises an import error" do
        before do
          allow(dialog_import_service).to receive(:store_for_import)
            .and_raise(DialogImportValidator::ImportNonYamlError)
        end

        it "redirects with an error message" do
          post :upload_import_file, :params => params, :xhr => true
          expect(controller.instance_variable_get(:@flash_array))
            .to include(:message => "Error: the file uploaded is not of the supported format", :level => :error)
        end
      end

      context "when the dialog importer raises a parse non dialog yaml error" do
        before do
          allow(dialog_import_service).to receive(:store_for_import)
            .and_raise(DialogImportValidator::ParsedNonDialogYamlError)
        end

        it "redirects with an error message" do
          post :upload_import_file, :params => params, :xhr => true
          expect(controller.instance_variable_get(:@flash_array))
            .to include(:message => "Error during upload: incorrect Dialog format, only service dialogs can be imported",
                        :level   => :error)
        end
      end

      context "when the dialog importer raises an invalid dialog field type error" do
        before do
          allow(dialog_import_service).to receive(:store_for_import)
            .and_raise(DialogImportValidator::InvalidDialogFieldTypeError)
        end

        it "redirects with an error message" do
          post :upload_import_file, :params => params, :xhr => true
          expect(controller.instance_variable_get(:@flash_array))
            .to include(:message => "Error during upload: one of the DialogField types is not supported",
                        :level   => :error)
        end
      end
    end

    context "when the upload parameter is nil" do
      let(:params) { {} }

      it_behaves_like "MiqAeCustomizationController#upload_import_file that does not upload a file"
    end

    context "when an upload file is not given" do
      let(:params) { {:upload => {:file => nil}} }

      it_behaves_like "MiqAeCustomizationController#upload_import_file that does not upload a file"
    end
  end

  describe "#import_service_dialogs" do
    include_context "valid session"

    let(:dialog_import_service) { double("DialogImportService") }
    let(:params) { {:import_file_upload_id => "123", :dialogs_to_import => ["potato"], :commit => 'Commit'} }
    let(:import_file_upload) { double("ImportFileUpload") }

    before do
      bypass_rescue
      allow(ImportFileUpload).to receive(:find_by).with(:id => "123").and_return(import_file_upload)
      allow(DialogImportService).to receive(:new).and_return(dialog_import_service)
      allow(controller).to receive(:get_node_info)
    end

    shared_examples_for "MiqAeCustomizationController#import_service_dialogs" do
      it "returns a status of 200" do
        post :import_service_dialogs, :params => params, :xhr => true
        expect(response.status).to eq(200)
      end
    end

    context "when the import file upload exists" do

      before do
        allow(dialog_import_service).to receive(:import_service_dialogs)
      end

      it_behaves_like "MiqAeCustomizationController#import_service_dialogs"

      it "imports the data" do
        expect(dialog_import_service).to receive(:import_service_dialogs).with(import_file_upload, ["potato"])
        post :import_service_dialogs, :params => params, :xhr => true
      end

      it "returns the flash message" do
        post :import_service_dialogs, :params => params, :xhr => true
        expect(controller.instance_variable_get(:@flash_array))
          .to include(:message => "Service dialogs imported successfully", :level => :success)
      end

      it "updates the dialogs tree" do
        expect(controller).to receive(:replace_right_cell).with(:nodetype => nil, :replace_trees => [:dialogs])
        post :import_service_dialogs, :params => params, :xhr => true
      end
    end

    context "when the import file upload does not exist" do
      let(:import_file_upload) { nil }

      it_behaves_like "MiqAeCustomizationController#import_service_dialogs"

      it "returns the flash message" do
        post :import_service_dialogs, :params => params, :xhr => true
        expect(controller.instance_variable_get(:@flash_array))
          .to include(:message => "Error: ImportFileUpload expired", :level => :error)
      end
    end

    context 'cancel import' do
      let(:params) { {:import_file_upload_id => "123", :dialogs_to_import => ["potato"]} }

      it "cancels the import" do
        expect(dialog_import_service).to receive(:cancel_import).with("123")
        post :import_service_dialogs, :params => params, :xhr => true
      end

      it "returns a 200" do
        expect(dialog_import_service).to receive(:cancel_import).with("123")
        post :import_service_dialogs, :params => params, :xhr => true
        expect(response.status).to eq(200)
      end

      it "returns the flash messages" do
        expect(dialog_import_service).to receive(:cancel_import).with("123")
        post :import_service_dialogs, :params => params, :xhr => true
        expect(controller.instance_variable_get(:@flash_array))
          .to include(:message => "Service dialog import cancelled", :level => :success)
      end
    end
  end

  describe "#export_service_dialogs" do
    include_context "valid session"

    let(:dialog_yaml_serializer) { double("DialogYamlSerializer") }
    let(:dialogs) { [double("Dialog")] }
    let(:params) { {:service_dialogs => service_dialogs} }

    before do
      bypass_rescue
    end

    context "when there are service dialogs" do
      let(:service_dialogs) { %w(1, 2, 3) }

      before do
        allow(DialogYamlSerializer).to receive(:new).and_return(dialog_yaml_serializer)
        allow(dialog_yaml_serializer).to receive(:serialize).with(dialogs).and_return("the dialog yml")
        allow(Dialog).to receive(:where).with(:id => service_dialogs).and_return(dialogs)
      end

      it "serializes given dialogs to yml" do
        expect(dialog_yaml_serializer).to receive(:serialize).with(dialogs)
        get :export_service_dialogs, :params => params
      end

      it "sends the data" do
        get :export_service_dialogs, :params => params
        expect(response.body).to eq("the dialog yml")
      end

      it "sets the filename to the current date" do
        Timecop.freeze(2013, 1, 2) do
          get :export_service_dialogs, :params => params
          expect(response.header['Content-Disposition']).to include("dialog_export_20130102_000000.yml")
        end
      end
    end

    context "when there are not service dialogs" do
      let(:service_dialogs) { nil }

      it "sets a flash message" do
        get :export_service_dialogs, :params => params
        expect(assigns(:flash_array))
          .to eq([{:message => "At least 1 item must be selected for export",
                   :level   => :error}])
      end

      it "sets the flash array on the sandbox" do
        get :export_service_dialogs, :params => params
        expect(assigns(:sb)[:flash_msg]).to eq([{:message => "At least 1 item must be selected for export",
                                                 :level   => :error}])
      end

      it "redirects to the explorer" do
        get :export_service_dialogs, :params => params
        expect(response).to redirect_to(:action => :explorer)
      end
    end
  end

  context "#x_button" do
    before :each do
      controller.instance_variable_set(:@sb, :applies_to_class => "EmsCluster")
      session[:sandboxes] = {
        "miq_ae_customization" => {
          :applies_to_class => "EmsCluster",
          :trees            => {
            :ab_tree => {:active_node => "-ub-EmsCluster"}
          },
          :active_tree      => :ab_tree
        }
      }
    end

    it "it should not call get_node_info when building new group add screen" do
      expect(controller).to_not receive(:get_node_info)
      post :x_button, :params => {:pressed => "ab_group_new"}
      expect(response.status).to eq(200)
      expect(response.body).to include("main_div")
    end
  end
end
