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

  describe "#cancel_import" do
    include_context "valid session"

    let(:params) { {:import_file_upload_id => "123"} }
    let(:automate_import_service) { instance_double("AutomateImportService") }

    before do
      bypass_rescue
      AutomateImportService.stub(:new).and_return(automate_import_service)
      automate_import_service.stub(:cancel_import)
    end

    it "cancels the import" do
      automate_import_service.should_receive(:cancel_import).with("123")
      xhr :post, :cancel_import, params
    end

    it "returns a 200" do
      xhr :post, :cancel_import, params
      expect(response.status).to eq(200)
    end

    it "returns the flash messages" do
      xhr :post, :cancel_import, params
      expect(response.body).to eq([{:message => "Datastore import was cancelled", :level => :info}].to_json)
    end
  end

  describe "#automate_json" do
    include_context "valid session"

    let(:automate_import_json_serializer) { instance_double("AutomateImportJsonSerializer") }
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload") }
    let(:params) { {:import_file_upload_id => "123"} }

    before do
      bypass_rescue
      AutomateImportJsonSerializer.stub(:new).and_return(automate_import_json_serializer)
      ImportFileUpload.stub(:find).with("123").and_return(import_file_upload)
      automate_import_json_serializer.stub(:serialize).with(import_file_upload).and_return("the json")
    end

    it "returns the expected json" do
      xhr :get, :automate_json, params
      expect(response.body).to eq("the json")
    end

    it "returns a 500 error code for invalid file" do
      automate_import_json_serializer.stub(:serialize).with(import_file_upload).and_raise(StandardError)
      xhr :get, :automate_json, params
      expect(response.status).to eq(500)
    end
  end

  describe "#import_automate_datastore" do
    include_context "valid session"

    let(:params) do
      {
        :import_file_upload_id          => "123",
        :selected_domain_to_import_from => "potato",
        :selected_domain_to_import_to   => "tomato",
        :selected_namespaces            => selected_namespaces
      }
    end

    before do
      bypass_rescue
    end

    context "when the selected namespaces is not nil" do
      let(:automate_import_service) { instance_double("AutomateImportService") }
      let(:selected_namespaces) { ["datastore/namespace", "datastore/namespace/test"] }

      before do
        ImportFileUpload.stub(:where).with(:id => "123").and_return([import_file_upload])
        AutomateImportService.stub(:new).and_return(automate_import_service)
      end

      context "when the import file exists" do
        let(:import_file_upload) { active_record_instance_double("ImportFileUpload") }
        let(:import_stats) do
          {
            :namespace => {:test => 2, :test2 => 2},
            :class     => {:test => 3, :test2 => 3},
            :instance  => {},
            :method    => {:test => 5, :test2 => 5},
          }
        end

        before do
          automate_import_service.stub(:import_datastore).and_return(import_stats)
        end

        it "imports the data" do
          automate_import_service.should_receive(:import_datastore).with(
            import_file_upload,
            "potato",
            "tomato",
            ["datastore", "datastore/namespace", "datastore/namespace/test"]
          )
          xhr :post, :import_automate_datastore, params
        end

        it "returns with a 200 status" do
          xhr :post, :import_automate_datastore, params
          expect(response.status).to eq(200)
        end

        it "returns the flash message" do
          xhr :post, :import_automate_datastore, params
          expected_message = <<-MESSAGE
Datastore import was successful.
Namespaces updated/added: 4
Classes updated/added: 6
Instances updated/added: 0
Methods updated/added: 10
          MESSAGE
          expect(response.body).to eq([{:message => expected_message.chomp, :level => :info}].to_json)
        end
      end

      context "when the import file does not exist" do
        let(:import_file_upload) { nil }

        it "returns with a 200 status" do
          xhr :post, :import_automate_datastore, params
          expect(response.status).to eq(200)
        end

        it "returns the flash message" do
          xhr :post, :import_automate_datastore, params
          expect(response.body).to eq(
            [{:message => "Error: Datastore import file upload expired", :level => :error}].to_json
          )
        end
      end
    end

    context "when the selected namepsaces is nil" do
      let(:selected_namespaces) { nil }

      it "returns with a 200 status" do
        xhr :post, :import_automate_datastore, params
        expect(response.status).to eq(200)
      end

      it "returns the flash message" do
        xhr :post, :import_automate_datastore, params
        expect(response.body).to eq(
          [{:message => "You must select at least one namespace to import", :level => :info}].to_json
        )
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
