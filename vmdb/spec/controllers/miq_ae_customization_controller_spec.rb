require "spec_helper"

describe MiqAeCustomizationController do
  before(:each) do
    set_user_privileges
  end

  context "#get_node_info" do
    it "Don't need to validate active node when editing Dialogs" do
      controller.instance_variable_set(:@sb, {:trees => {:dialog_edit_tree => {:active_node => "root"}}, :active_tree => :dialog_edit_tree})
      controller.should_not_receive(:valid_active_node)
      controller.should_receive(:dialog_edit_set_form_vars)
      controller.send(:get_node_info)
    end
  end

  describe "group_reorder_field_changed" do
    before(:each) do
      controller.stub(:load_edit).and_return(true)
      controller.instance_variable_set(:@edit, {:new => {:fields => [['test',100], ['test1',101], ['test2',102], ['test3', 103]]}})
    end

    context "#move_cols_up" do
      it "move one button up" do
        post :group_reorder_field_changed, :id => 'seq', :button => 'up', 'selected_fields'=> ['101']
        expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['test1',101], ['test',100], ['test2',102], ['test3', 103]] }} )
      end

      it "move 2 button up" do
        post :group_reorder_field_changed, :id => 'seq', :button => 'up', 'selected_fields'=> ['101', '102']
        expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['test1',101], ['test2',102], ['test',100], ['test3', 103]] }} )
      end
    end

    context "#move_cols_down" do
      it "move one button down" do
        post :group_reorder_field_changed, :id => 'seq', :button => 'down', 'selected_fields'=> ['101']
        expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['test',100], ['test2',102], ['test1',101], ['test3', 103]] }} )
      end

      it "move 2 buttons down" do
        post :group_reorder_field_changed, :id => 'seq', :button => 'down', 'selected_fields'=> ['101','102']
        expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['test',100], ['test3',103], ['test1',101], ['test2', 102]] }} )
      end
    end

    context "no button selected" do
      it "moves up and display error message" do
        post :group_reorder_field_changed, :id => 'seq', :button => 'up'
        expect(response.body).to include("flash")
      end

      it "moves down and display error message" do
        post :group_reorder_field_changed, :id => 'seq', :button => 'down'
        expect(response.body).to include("flash")
      end
    end

    context "all buttons selected" do
      pending "for when we redesign rotate functionality" do
        it "moves up and rotate whole group" do
          post :group_reorder_field_changed, :id => 'seq', :button => 'up', 'selected_fields'=> ['100','101','102','103']
          expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['test1',101], ['test2',102], ['test3',103], ['test', 100]] }} )
        end

        it "moves down and rotate opposite whole group" do
          post :group_reorder_field_changed, :id => 'seq', :button => 'down', 'selected_fields'=> ['100','101','102','103']
          expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['test3',103], ['test',100], ['test1',101], ['test2', 102]] }} )
        end
      end
    end

  end

  describe "#group_form_field_changed" do
    before(:each) do
      controller.stub(:load_edit).and_return(true)
      controller.instance_variable_set(:@edit, {:new => {:fields => [['value',100], ['value1',101], ['value2',102], ['value3', 103]]}})
    end

    context "assign buttons" do

      it "moves button up" do
        post :group_form_field_changed, 'selected_fields'=>['101'], :button => 'up'
        expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['value1',101], ['value',100], ['value2',102], ['value3', 103]] }} )
      end

      it "moves button down" do
        post :group_form_field_changed, 'selected_fields'=>['101'], :button => 'down'
        expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['value',100], ['value2',102], ['value1',101], ['value3', 103]] }} )
      end

      it "moves button to the top" do
        post :group_form_field_changed, 'selected_fields'=>['101'], :button => 'top'
        expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['value1',101], ['value',100], ['value2',102], ['value3', 103]] }} )
      end

      it "moves button to the bottom" do
        post :group_form_field_changed, 'selected_fields'=>['101'], :button => 'bottom'
        expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['value',100], ['value2',102], ['value3',103], ['value1', 101]] }} )
      end

      context "no selected button" do

        it "moves up and display error message" do
          post :group_form_field_changed, :button => 'up'
          expect(response.body).to include("flash")
        end

        it "moves down and display error message" do
          post :group_form_field_changed, :button => 'down'
          expect(response.body).to include("flash")
        end

        it "moves up and display error message" do
          post :group_form_field_changed, :button => 'top'
          expect(response.body).to include("flash")
        end

        it "moves down and display error message" do
          post :group_form_field_changed, :button => 'bottom'
          expect(response.body).to include("flash")
        end

      end

      context "all buttons selected" do
        pending "for when we redesign rotate functionality" do
          it "moves up and rotate whole group" do
            post :group_form_field_changed, :button => 'up', 'selected_fields'=> ['100','101','102','103']
            expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['value1',101], ['value2',102], ['value3',103], ['value', 100]] }} )
          end

          it "moves down and rotate opposite whole group" do
            post :group_form_field_changed, :button => 'down', 'selected_fields'=> ['100','101','102','103']
            expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['value3',103], ['value',100], ['value1',101], ['value2', 102]] }} )
          end
        end

        it "moves to the top and nothing happen" do
          post :group_form_field_changed, :button => 'top', 'selected_fields'=> ['100','101','102','103']
          expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['value',100], ['value1',101], ['value2',102], ['value3', 103]] }} )
        end

        it "moves to the bottom and nothing happen" do
          post :group_form_field_changed, :button => 'bottom', 'selected_fields'=> ['100','101','102','103']
          expect(controller.instance_variable_get(:@edit)).to eql({:new => {:fields => [['value',100], ['value1',101], ['value2',102], ['value3', 103]] }} )
        end
      end

    end
  end

  describe 'x_button' do
    before(:each) do
      described_class.any_instance.stub(:set_user_time_zone)
      controller.stub(:check_privileges).and_return(true)
    end

    describe 'corresponding methods are called for allowed actions' do
      MiqAeCustomizationController::AE_CUSTOM_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
        it "calls the appropriate method: '#{method}' for action '#{action_name}'" do
          controller.should_receive(method)
          get :x_button, :pressed => action_name
        end
      end
    end

    it 'exception is raised for unknown action' do
      get :x_button, :pressed => 'random_dude', :format => :html
      expect { response }.to render_template('layouts/exception')
    end
  end

  describe "#explorer" do
    include_context "valid session"

    let(:sandbox_flash_messages) { nil }

    before do
      controller.instance_variable_set(:@sb, {:flash_msg => sandbox_flash_messages})
      bypass_rescue
    end

    it "assigns the sandbox active tree" do
      get :explorer
      assigns(:sb)[:active_tree].should == :old_dialogs_tree
    end

    it "assigns the sandbox active accord" do
      get :explorer
      assigns(:sb)[:active_accord].should == :old_dialogs
    end

    it "assigns the sandbox active node on old dialogs tree to root" do
      get :explorer
      assigns(:sb)[:active_node][:old_dialogs_tree].should == "root"
    end

    it "builds the old dialogs tree" do
      get :explorer
      assigns(:built_trees)[0].name == :old_dialogs_tree
    end

    it "assigns the sandbox active node on dialogs tree to root" do
      get :explorer
      assigns(:sb)[:active_node][:dialogs_tree].should == "root"
    end

    it "builds the dialog tree" do
      get :explorer
      assigns(:built_trees)[1].name.should == :dialogs_tree
    end

    it "assigns the sandbox active node on ab tree to root" do
      get :explorer
      assigns(:sb)[:active_node][:ab_tree].should == "root"
    end

    it "builds the ab tree" do
      get :explorer
      assigns(:built_trees)[2].name.should == :ab_tree
    end

    it "assigns the sandbox active node on import/export tree to root" do
      get :explorer
      assigns(:sb)[:active_node][:dialog_import_export_tree].should == "root"
    end

    it "builds the import/export tree" do
      get :explorer
      assigns(:built_trees)[3].name.should == :dialog_import_export_tree
    end

    context "when the sandbox has flash messages" do
      let(:sandbox_flash_messages) { ["the flash messages"] }

      before do
        controller.stub(:get_global_session_data)
        controller.instance_variable_set(:@temp, {})
      end

      it "includes the flash messages from the sandbox" do
        get :explorer
        assigns(:flash_array).should include("the flash messages")
      end
    end

    context "when the sandbox does not have flash messages" do
      it "does not include the flash message from the sandbox" do
        get :explorer
        assigns(:flash_array).should_not include("the flash messages")
      end
    end
  end

  describe "#upload_import_file" do
    include_context "valid session"

    let(:dialog_importer) { instance_double("DialogImporter") }

    before do
      bypass_rescue
    end

    shared_examples_for "MiqAeCustomizationController#upload_import_file that does not upload a file" do
      it "redirects with a warning message" do
        xhr :post, :upload_import_file, params
        response.should redirect_to(
          :action  => :review_import,
          :message => {:message => "Use the browse button to locate an import file", :level => :warning}.to_json
        )
      end
    end

    context "when an upload file is given" do
      let(:filename) { "filename" }
      let(:file) { fixture_file_upload(Rails.root.join("spec/fixtures/files/import_service_dialog.yml"), "text/yml") }
      let(:params) { {:upload => {:file => file}} }

      before do
        DialogImporter.stub(:new).and_return(dialog_importer)
      end

      context "when the dialog importer does not raise an error" do
        before do
          dialog_importer.stub(:store_for_import).with("the yaml data").and_return(123)
          file.stub(:read).and_return("the yaml data")
        end

        it "redirects to review_import with an import file upload id" do
          xhr :post, :upload_import_file, params
          response.should redirect_to(
            :action                => :review_import,
            :import_file_upload_id => 123,
            :message               => {:message => "Import file was uploaded successfully", :level => :info}.to_json
          )
        end

        it "imports the dialogs" do
          dialog_importer.should_receive(:store_for_import).with("the yaml data")
          xhr :post, :upload_import_file, params
        end
      end

      context "when the dialog importer raises an import error" do
        before do
          dialog_importer.stub(:store_for_import).and_raise(DialogImportValidator::ImportNonYamlError)
        end

        it "redirects with an error message" do
          xhr :post, :upload_import_file, params
          response.should redirect_to(
            :action  => :review_import,
            :message => {
              :message => "Error: the file uploaded is not of the supported format",
              :level   => :error
            }.to_json
          )
        end
      end

      context "when the dialog importer raises a parse non dialog yaml error" do
        before do
          dialog_importer.stub(:store_for_import).and_raise(DialogImportValidator::ParsedNonDialogYamlError)
        end

        it "redirects with an error message" do
          xhr :post, :upload_import_file, params
          response.should redirect_to(
            :action  => :review_import,
            :message => {
              :message => "Error during upload: incorrect Dialog format, only service dialogs can be imported",
              :level   => :error
            }.to_json
          )
        end
      end

      context "when the dialog importer raises an invalid dialog field type error" do
        before do
          dialog_importer.stub(:store_for_import).and_raise(DialogImportValidator::InvalidDialogFieldTypeError)
        end

        it "redirects with an error message" do
          xhr :post, :upload_import_file, params
          response.should redirect_to(
            :action  => :review_import,
            :message => {
              :message => "Error during upload: one of the DialogField types is not supported",
              :level   => :error
            }.to_json
          )
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

    let(:dialog_importer) { instance_double("DialogImporter") }
    let(:params) { {:import_file_upload_id => "123", :dialogs_to_import => ["potato"]} }

    before do
      bypass_rescue
      ImportFileUpload.stub(:first).with(:conditions => {:id => "123"}).and_return(import_file_upload)
      DialogImporter.stub(:new).and_return(dialog_importer)
    end

    shared_examples_for "MiqAeCustomizationController#import_service_dialogs" do
      it "returns a status of 200" do
        xhr :post, :import_service_dialogs, params
        response.status.should == 200
      end
    end

    context "when the import file upload exists" do
      let(:import_file_upload) do
        instance_double("ImportFileUpload")
      end

      before do
        dialog_importer.stub(:import_service_dialogs)
      end

      it_behaves_like "MiqAeCustomizationController#import_service_dialogs"

      it "imports the data" do
        dialog_importer.should_receive(:import_service_dialogs).with(import_file_upload, ["potato"])
        xhr :post, :import_service_dialogs, params
      end

      it "returns the flash message" do
        xhr :post, :import_service_dialogs, params
        response.body.should == [{:message => "Service dialogs imported successfully", :level => :info}].to_json
      end
    end

    context "when the import file upload does not exist" do
      let(:import_file_upload) { nil }

      it_behaves_like "MiqAeCustomizationController#import_service_dialogs"

      it "returns the flash message" do
        xhr :post, :import_service_dialogs, params
        response.body.should == [{:message => "Error: ImportFileUpload expired", :level => :error}].to_json
      end
    end
  end

  describe "#review_import" do
    include_context "valid session"

    let(:params) { {:import_file_upload_id => "123", :message => "the message"} }

    before do
      bypass_rescue
    end

    it "assigns the import file upload id" do
      get :review_import, params
      assigns(:import_file_upload_id).should == "123"
    end

    it "assigns the message" do
      get :review_import, params
      assigns(:message).should == "the message"
    end
  end

  describe "#cancel_import" do
    include_context "valid session"

    let(:params) { {:import_file_upload_id => "123"} }
    let(:dialog_importer) { instance_double("DialogImporter") }

    before do
      bypass_rescue
      DialogImporter.stub(:new).and_return(dialog_importer)
      dialog_importer.stub(:cancel_import)
    end

    it "cancels the import" do
      dialog_importer.should_receive(:cancel_import).with("123")
      xhr :post, :cancel_import, params
    end

    it "returns a 200" do
      xhr :post, :cancel_import, params
      response.status.should == 200
    end

    it "returns the flash messages" do
      xhr :post, :cancel_import, params
      response.body.should == [{:message => "Service dialog import cancelled", :level => :info}].to_json
    end
  end

  describe "#service_dialog_json" do
    include_context "valid session"

    let(:params) { {:import_file_upload_id => "123"} }
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload") }

    before do
      bypass_rescue
      ImportFileUpload.stub(:find).with("123").and_return(import_file_upload)
      import_file_upload.stub(:service_dialog_json).and_return("the service dialog json")
    end

    it "returns the json" do
      xhr :get, :service_dialog_json, params
      response.body.should == "the service dialog json"
    end
  end

  describe "#export_service_dialogs" do
    include_context "valid session"

    let(:dialog_yaml_serializer) { instance_double("DialogYamlSerializer") }
    let(:dialogs) { [active_record_instance_double("Dialog")] }
    let(:params) { {:service_dialogs => service_dialogs} }

    before do
      bypass_rescue
    end

    context "when there are service dialogs" do
      let(:service_dialogs) { %w(1, 2, 3) }

      before do
        DialogYamlSerializer.stub(:new).and_return(dialog_yaml_serializer)
        dialog_yaml_serializer.stub(:serialize).with(dialogs).and_return("the dialog yml")
        Dialog.stub(:where).with(:id => service_dialogs).and_return(dialogs)
      end

      it "serializes given dialogs to yml" do
        dialog_yaml_serializer.should_receive(:serialize).with(dialogs)
        get :export_service_dialogs, params
      end

      it "sends the data" do
        get :export_service_dialogs, params
        response.body.should == "the dialog yml"
      end

      it "sets the filename to the current date" do
        Timecop.freeze(2013, 1, 2) do
          get :export_service_dialogs, params
          response.header['Content-Disposition'].should include("dialog_export_20130102_000000.yml")
        end
      end
    end

    context "when there are not service dialogs" do
      let(:service_dialogs) { nil }

      it "sets a flash message" do
        get :export_service_dialogs, params
        assigns(:flash_array).should == [{
          :message => "At least 1 item must be selected for export",
          :level   => :error
        }]
      end

      it "sets the flash array on the sandbox" do
        get :export_service_dialogs, params
        assigns(:sb)[:flash_msg].should == [{
          :message => "At least 1 item must be selected for export",
          :level   => :error
        }]
      end

      it "redirects to the explorer" do
        get :export_service_dialogs, params
        response.should redirect_to(:action => :explorer)
      end
    end
  end
end
