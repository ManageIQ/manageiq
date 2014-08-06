require "spec_helper"

describe MiqAeToolsController do
  before(:each) do
    set_user_privileges
  end

  context "#form_field_changed" do
    it "resets target id to nil, when target class is <none>" do
      new = {
        :target_class => "EmsCluster",
        :target_id    => 1
      }
      controller.instance_variable_set(:@resolve, :throw_ready => true, :new => new)
      controller.should_receive(:render)
      controller.instance_variable_set(:@_params, :target_class => '', :id => 'new')
      controller.send(:form_field_changed)
      assigns(:resolve)[:new][:target_class].should eq('')
      assigns(:resolve)[:new][:target_id].should eq(nil)
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

  describe "#upload_import_file" do
    include_context "valid session"

    before do
      bypass_rescue
    end

    shared_examples_for "MiqAeToolsController#upload_import_file that does not upload a file" do
      it "redirects with a warning message" do
        xhr :post, :upload_import_file, params
        response.should redirect_to(
          :action  => :review_import,
          :message => {:message => "Use the browse button to locate an import file", :level => :warning}.to_json
        )
      end
    end

    context "when an upload file is given" do
      let(:automate_import_service) { instance_double("AutomateImportService") }
      let(:params) { {:upload => {:file => upload_file}} }
      let(:upload_file) { fixture_file_upload(Rails.root.join("spec/fixtures/files/import_automate.yml"), "text/yml") }

      before do
        AutomateImportService.stub(:new).and_return(automate_import_service)
        automate_import_service.stub(:store_for_import).with("the yaml data").and_return(123)
        upload_file.stub(:read).and_return("the yaml data")
      end

      it "stores the file for import" do
        automate_import_service.should_receive(:store_for_import).with("the yaml data")
        xhr :post, :upload_import_file, params
      end

      it "redirects to review_import" do
        xhr :post, :upload_import_file, params
        response.should redirect_to(
          :action                => :review_import,
          :import_file_upload_id => 123,
          :message               => {:message => "Import file was uploaded successfully", :level => :info}.to_json
        )
      end
    end

    context "when the upload parameter is nil" do
      let(:params) { {} }

      it_behaves_like "MiqAeToolsController#upload_import_file that does not upload a file"
    end

    context "when an upload file is not given" do
      let(:params) { {:upload => {:file => nil}} }

      it_behaves_like "MiqAeToolsController#upload_import_file that does not upload a file"
    end
  end
end
