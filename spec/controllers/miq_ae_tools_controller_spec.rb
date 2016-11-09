describe MiqAeToolsController do
  before(:each) do
    stub_user(:features => :all)
  end

  context "#form_field_changed" do
    it "resets target id to nil, when target class is <none>" do
      new = {
        :target_class => "EmsCluster",
        :target_id    => 1
      }
      controller.instance_variable_set(:@resolve, :throw_ready => true, :new => new)
      expect(controller).to receive(:render)
      controller.instance_variable_set(:@_params, :target_class => 'Vm', :id => 'new')
      controller.send(:form_field_changed)
      expect(assigns(:resolve)[:new][:target_class]).to eq('Vm')
      expect(assigns(:resolve)[:new][:target_id]).to eq(nil)
      expect(assigns(:resolve)[:targets].count).to eq(0)
    end
  end

  describe "#import_export" do
    include_context "valid session"

    let(:fake_domain) { double("MiqAeDomain", :name => "test_domain") }
    let(:fake_domain2) { double("MiqAeDomain", :name => "uneditable") }
    let(:tenant) do
      double(
        "Tenant",
        :editable_domains => [double(:name => "test_domain")]
      )
    end

    before do
      bypass_rescue
      allow(controller).to receive(:current_tenant).and_return(tenant)
      allow(MiqAeDomain).to receive(:all_unlocked).and_return([fake_domain, fake_domain2])
    end

    it "includes a list of importable domain options" do
      get :import_export

      expect(assigns(:importable_domain_options)).to eq([
        ["<Same as import from>", nil],
        %w(test_domain test_domain)
      ])
    end
  end

  describe "#cancel_import" do
    include_context "valid session"

    let(:params) { {:import_file_upload_id => "123"} }
    let(:automate_import_service) { double("AutomateImportService") }

    before do
      bypass_rescue
      allow(AutomateImportService).to receive(:new).and_return(automate_import_service)
      allow(automate_import_service).to receive(:cancel_import)
    end

    it "cancels the import" do
      expect(automate_import_service).to receive(:cancel_import).with("123")
      post :cancel_import, :params => params, :xhr => true
    end

    it "returns a 200" do
      post :cancel_import, :params => params, :xhr => true
      expect(response.status).to eq(200)
    end

    it "returns the flash messages" do
      post :cancel_import, :params => params, :xhr => true
      expect(response.body).to eq([{:message => "Datastore import was cancelled or is finished", :level => :info}].to_json)
    end
  end

  describe "#automate_json" do
    include_context "valid session"

    let(:automate_import_json_serializer) { double("AutomateImportJsonSerializer") }
    let(:import_file_upload) { double("ImportFileUpload") }
    let(:params) { {:import_file_upload_id => "123"} }

    before do
      bypass_rescue
      allow(AutomateImportJsonSerializer).to receive(:new).and_return(automate_import_json_serializer)
      allow(ImportFileUpload).to receive(:find).with("123").and_return(import_file_upload)
      allow(automate_import_json_serializer).to receive(:serialize).with(import_file_upload).and_return("the json")
    end

    it "returns the expected json" do
      get :automate_json, :params => params, :xhr => true
      expect(response.body).to eq("the json")
    end

    it "returns a 500 error code for invalid file" do
      allow(automate_import_json_serializer).to receive(:serialize).with(import_file_upload).and_raise(StandardError)
      get :automate_json, :params => params, :xhr => true
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
      let(:automate_import_service) { double("AutomateImportService") }
      let(:selected_namespaces) { ["datastore/namespace", "datastore/namespace/test"] }

      before do
        allow(ImportFileUpload).to receive(:where).with(:id => "123").and_return([import_file_upload])
        allow(AutomateImportService).to receive(:new).and_return(automate_import_service)
      end

      context "when the import file exists" do
        let(:import_file_upload) { double("ImportFileUpload") }
        let(:import_stats) do
          {
            :namespace => {:test => 2, :test2 => 2},
            :class     => {:test => 3, :test2 => 3},
            :instance  => {},
            :method    => {:test => 5, :test2 => 5},
          }
        end

        before do
          allow(automate_import_service).to receive(:import_datastore).and_return(import_stats)
        end

        it "imports the data" do
          expect(automate_import_service).to receive(:import_datastore).with(
            import_file_upload,
            "potato",
            "tomato",
            ["datastore", "datastore/namespace", "datastore/namespace/test"]
          )
          post :import_automate_datastore, :params => params, :xhr => true
        end

        it "returns with a 200 status" do
          post :import_automate_datastore, :params => params, :xhr => true
          expect(response.status).to eq(200)
        end

        it "returns the flash message" do
          post :import_automate_datastore, :params => params, :xhr => true
          expected_message = <<-MESSAGE
Datastore import was successful.
Namespaces updated/added: 4
Classes updated/added: 6
Instances updated/added: 0
Methods updated/added: 10
          MESSAGE
          expect(response.body).to eq([{:message => expected_message.chomp, :level => :success}].to_json)
        end
      end

      context "when the import file does not exist" do
        let(:import_file_upload) { nil }

        it "returns with a 200 status" do
          post :import_automate_datastore, :params => params, :xhr => true
          expect(response.status).to eq(200)
        end

        it "returns the flash message" do
          post :import_automate_datastore, :params => params, :xhr => true
          expect(response.body).to eq(
            [{:message => "Error: Datastore import file upload expired", :level => :error}].to_json
          )
        end
      end
    end

    context "when the selected namepsaces is nil" do
      let(:selected_namespaces) { nil }

      it "returns with a 200 status" do
        post :import_automate_datastore, :params => params, :xhr => true
        expect(response.status).to eq(200)
      end

      it "returns the flash message" do
        post :import_automate_datastore, :params => params, :xhr => true
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
      get :review_import, :params => params
      expect(assigns(:import_file_upload_id)).to eq("123")
    end

    it "assigns the message" do
      get :review_import, :params => params
      expect(assigns(:message)).to eq("the message")
    end
  end

  describe "#review_git_import" do
    include_context "valid session"

    let(:params) do
      {:git_branches => "git_branches", :git_tags => "git_tags", :git_repo_id => "123", :message => "the message"}
    end

    before do
      bypass_rescue
    end

    it "assigns the git repo id" do
      get :review_git_import, :params => params
      expect(assigns(:git_repo_id)).to eq("123")
    end

    it "assigns the git branches" do
      get :review_git_import, :params => params
      expect(assigns(:git_branches)).to eq("git_branches")
    end

    it "assigns the git tags" do
      get :review_git_import, :params => params
      expect(assigns(:git_tags)).to eq("git_tags")
    end

    it "assigns the message" do
      get :review_git_import, :params => params
      expect(assigns(:message)).to eq("the message")
    end
  end

  describe "#retrieve_git_datastore" do
    include_context "valid session"

    let(:params) do
      {:git_url => git_url, :git_username => nil, :git_password => nil, :git_verify_ssl => git_verify_ssl}
    end

    context "when the git url is blank" do
      let(:git_url) { "" }
      let(:git_verify_ssl) { "true" }

      it "redirects with a flash error" do
        post :retrieve_git_datastore, :params => params
        expect(response).to redirect_to(
          :action  => :review_git_import,
          :message => {
            :message => "Please provide a valid git URL",
            :level   => :error
          }.to_json
        )
      end
    end

    context "when the git url is not blank" do
      let(:git_url) { "git_url" }
      let(:git_verify_ssl) { "true" }
      let(:my_region) { double("MiqRegion") }

      before do
        allow(MiqRegion).to receive(:my_region).and_return(my_region)
        allow(my_region).to receive(:role_active?).with("git_owner").and_return(git_owner_active)
      end

      context "when the MiqRegion does not have an active git_owner role" do
        let(:git_owner_active) { false }

        it "redirects with a flash error" do
          post :retrieve_git_datastore, :params => params
          expect(response).to redirect_to(
            :action  => :review_git_import,
            :message => {
              :message => "Please enable the git owner role in order to import git repositories",
              :level   => :error
            }.to_json
          )
        end
      end

      context "when the MiqRegion has an active git_owner role" do
        let(:verify_ssl) { OpenSSL::SSL::VERIFY_PEER }
        let(:git_owner_active) { true }
        let(:git_repo) { double("GitRepository", :id => 321) }
        let(:git_branches) { [double("GitBranch", :name => "git_branch1")] }
        let(:git_tags) { [double("GitTag", :name => "git_tag1")] }
        let(:task_options) { {:action => "Retrieve git repository", :userid => controller.current_user.userid} }
        let(:queue_options) do
          {
            :class_name  => "GitRepository",
            :method_name => "refresh",
            :instance_id => 321,
            :role        => "git_owner",
            :args        => []
          }
        end

        before do
          allow(GitRepository).to receive(:create).with(:url => git_url, :verify_ssl => verify_ssl).and_return(git_repo)
          allow(git_repo).to receive(:update_authentication).with(:values => {:userid => "", :password => ""})
          allow(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options).and_return(1234)
          allow(MiqTask).to receive(:wait_for_taskid).with(1234)
          allow(git_repo).to receive(:git_branches).and_return(git_branches)
          allow(git_repo).to receive(:git_tags).and_return(git_tags)
        end

        context "when the git repository exists with the given url" do
          before do
            allow(GitRepository).to receive(:exists?).with(:url => git_url).and_return(true)
          end

          it "queues the refresh action" do
            expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
            post :retrieve_git_datastore, :params => params
          end

          it "waits for the refresh action" do
            expect(MiqTask).to receive(:wait_for_taskid).with(1234)
            post :retrieve_git_datastore, :params => params
          end

          it "adds a warning flash message with the other redirect options" do
            post :retrieve_git_datastore, :params => params
            expect(response).to redirect_to(
              :action       => :review_git_import,
              :git_branches => ["git_branch1"].to_json,
              :git_tags     => ["git_tag1"].to_json,
              :git_repo_id  => 321,
              :message      => {
                :message => "This repository has been used previously for imports; If you use the same domain it will get deleted and recreated",
                :level   => :warning
              }.to_json
            )
          end
        end

        context "when the repository is using self signed certificates" do
          let (:verify_ssl) { OpenSSL::SSL::VERIFY_NONE }
          let (:git_verify_ssl) { "false" }

          before do
            allow(GitRepository).to receive(:exists?).with(:url => git_url).and_return(false)
          end
          it "queues the refresh action" do
            expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
            post :retrieve_git_datastore, :params => params
          end
        end

        context "when the git repository does not exist with the given url" do
          before do
            allow(GitRepository).to receive(:exists?).with(:url => git_url).and_return(false)
          end

          it "queues the refresh action" do
            expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
            post :retrieve_git_datastore, :params => params
          end

          it "waits for the refresh action" do
            expect(MiqTask).to receive(:wait_for_taskid).with(1234)
            post :retrieve_git_datastore, :params => params
          end

          it "adds a success flash message with the other redirect options" do
            post :retrieve_git_datastore, :params => params
            expect(response).to redirect_to(
              :action       => :review_git_import,
              :git_branches => ["git_branch1"].to_json,
              :git_tags     => ["git_tag1"].to_json,
              :git_repo_id  => 321,
              :message      => {
                :message => "Successfully found git repository, please choose a branch or tag",
                :level   => :success
              }.to_json
            )
          end
        end
      end
    end
  end

  describe "#upload_import_file" do
    include_context "valid session"

    before do
      bypass_rescue
    end

    shared_examples_for "MiqAeToolsController#upload_import_file that does not upload a file" do
      it "redirects with a warning message" do
        post :upload_import_file, :params => params, :xhr => true
        expect(response).to redirect_to(
          :action  => :review_import,
          :message => {:message => "Use the Choose file button to locate an import file", :level => :warning}.to_json
        )
      end
    end

    context "when an upload file is given" do
      let(:automate_import_service) { double("AutomateImportService") }
      let(:params) { {:upload => {:file => upload_file}} }
      let(:upload_file) { fixture_file_upload("files/dummy_file.yml", "text/yml") }

      before do
        allow(AutomateImportService).to receive(:new).and_return(automate_import_service)
        allow(automate_import_service).to receive(:store_for_import).with("the yaml data\n").and_return(123)
      end

      it "stores the file for import" do
        expect(automate_import_service).to receive(:store_for_import).with("the yaml data\n")
        post :upload_import_file, :params => params, :xhr => true
      end

      it "redirects to review_import" do
        post :upload_import_file, :params => params, :xhr => true
        expect(response).to redirect_to(
          :action                => :review_import,
          :import_file_upload_id => 123,
          :message               => {:message => "Import file was uploaded successfully", :level => :success}.to_json
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

  describe "#import_via_git" do
    let(:params) { {:git_repo_id => "123", :git_branch_or_tag => "branch_or_tag"} }
    let(:git_based_domain_import_service) { double("GitBasedDomainImportService") }

    before do
      allow(GitBasedDomainImportService).to receive(:new).and_return(git_based_domain_import_service)
    end

    context "when there are no errors while importing" do
      before do
        tenant_id = controller.current_tenant.id
        allow(git_based_domain_import_service).to receive(:import).with("123", "branch_or_tag", tenant_id)
      end

      it "responds with a success message" do
        post :import_via_git, :params => params, :xhr => true
        expect(response.body).to eq([{:message => "Imported from git", :level => :info}].to_json)
      end
    end

    context "when there are errors while importing" do
      before do
        tenant_id = controller.current_tenant.id
        allow(git_based_domain_import_service).to receive(:import).with("123", "branch_or_tag", tenant_id).and_raise(
          MiqException::Error, "kaboom"
        )
      end

      it "responds with an error message" do
        post :import_via_git, :params => params, :xhr => true
        expect(response.body).to eq(
          [{:message => "Error: import failed: kaboom", :level => :error}].to_json
        )
      end
    end
  end
end
