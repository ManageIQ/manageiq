describe MiqPolicyController do
  before(:each) do
    stub_user(:features => :all)
  end

  describe "#import" do
    include_context "valid session"

    let(:params) { {:import_file_upload_id => 123, :commit => commit} }
    let(:miq_policy_import_service) { double("MiqPolicyImportService") }

    before do
      allow(MiqPolicyImportService).to receive(:new).and_return(miq_policy_import_service)
    end

    shared_examples_for "MiqPolicyController#import" do
      it "assigns the import file upload id" do
        post :import, :params => params
        expect(assigns(:import_file_upload_id)).to eq("123")
      end
    end

    context "when the commit parameter is import" do
      let(:commit) { "import" }

      before do
        allow(miq_policy_import_service).to receive(:import_policy)
      end

      it_behaves_like "MiqPolicyController#import"

      it "imports a policy" do
        expect(miq_policy_import_service).to receive(:import_policy).with("123")
        post :import, :params => params
      end
    end

    context "when the commit parameter is cancel" do
      let(:commit) { "cancel" }

      before do
        allow(miq_policy_import_service).to receive(:cancel_import)
      end

      it_behaves_like "MiqPolicyController#import"

      it "cancels the import" do
        expect(miq_policy_import_service).to receive(:cancel_import).with("123")
        post :import, :params => params
      end
    end
  end

  describe "#upload" do
    include_context "valid session"

    shared_examples_for "MiqPolicyController#upload that cannot locate an import file" do
      it "redirects with a cannot locate import file error message" do
        post :upload, :params => params
        expect(response).to redirect_to(
          :action      => "export",
          :dbtype      => "dbtype",
          :flash_msg   => "Use the Choose file button to locate an Import file",
          :flash_error => true
        )
      end
    end

    let(:params) { {:dbtype => "dbtype", :upload => upload} }

    context "when there is an upload parameter" do
      let(:upload) { {:file => file_contents} }

      context "when there is a file upload parameter" do
        context "when the file upload parameter responds to read" do
          let(:file_contents) do
            fixture_file_upload("files/dummy_file.yml", "text/yml")
          end

          let(:miq_policy_import_service) { double("MiqPolicyImportService") }

          before do
            allow(MiqPolicyImportService).to receive(:new).and_return(miq_policy_import_service)
          end

          context "when there is not an error while importing" do
            let(:import_file_upload) { double("ImportFileUpload", :id => 123) }

            before do
              allow(miq_policy_import_service).to receive(:store_for_import).and_return(import_file_upload)
            end

            it "sets the sandbox hide variable to true" do
              post :upload, :params => params
              expect(assigns(:sb)[:hide]).to be_truthy
            end

            it "imports a policy" do
              expect(miq_policy_import_service).to receive(:store_for_import).with(an_instance_of(ActionDispatch::Http::UploadedFile))
              post :upload, :params => params
            end

            it "redirects to import with the import_file_upload_id" do
              post :upload, :params => params
              expect(response).to redirect_to(:action => "import", :dbtype => "dbtype", :import_file_upload_id => 123)
            end
          end

          context "when there is an error while importing" do
            before do
              allow(miq_policy_import_service).to receive(:store_for_import)
                .with(an_instance_of(ActionDispatch::Http::UploadedFile)).and_raise(StandardError.new("message"))
            end

            it "redirects to export with an error message" do
              post :upload, :params => params
              expect(response).to redirect_to(
                :action      => "export",
                :dbtype      => "dbtype",
                :flash_msg   => "Error during 'Policy Import': message",
                :flash_error => true
              )
            end
          end
        end

        context "when the file upload parameter does not respond to read" do
          let(:file_contents) { "does not respond to read" }

          it_behaves_like "MiqPolicyController#upload that cannot locate an import file"
        end
      end

      context "when there is not a file upload parameter" do
        let(:file_contents) { nil }

        it_behaves_like "MiqPolicyController#upload that cannot locate an import file"
      end
    end

    context "when there is not an upload parameter" do
      let(:upload) { nil }

      it_behaves_like "MiqPolicyController#upload that cannot locate an import file"
    end
  end

  describe '#explorer' do
    context 'when profile param present, but non-existent' do
      it 'renders explorer with flash message' do
        post :explorer, :params => { :profile => 42 }
        expect(response).to render_template('explorer')
        flash_messages = controller.instance_variable_get(:@flash_array)
        expect(flash_messages.find { |m| m[:message] == 'Policy Profile no longer exists' }).not_to be_nil
      end
    end

    context 'when profile param not present' do
      it 'renders explorer w/o flash message' do
        post :explorer
        expect(response).to render_template('explorer')
        flash_messages = controller.instance_variable_get(:@flash_array)
        expect(flash_messages).to be_nil
      end
    end

    context 'when profile param is valid' do
      it 'renders explorer w/o flash and assigns to x_node' do
        profile = FactoryGirl.create(:miq_policy_set)
        allow(controller).to receive(:get_node_info).and_return(true)
        post :explorer, :params => { :profile => profile.id }
        expect(response).to render_template('explorer')
        flash_messages = controller.instance_variable_get(:@flash_array)
        expect(flash_messages).to be_nil
        expect(controller.x_node).to eq("pp_#{profile.id}")
      end
    end
  end

  describe '#tree_select' do
    [
      # [tree_sym, node, partial_name]
      [:policy_profile_tree, 'root', 'miq_policy/_profile_list'],
      [:policy_tree, 'root', 'miq_policy/_policy_folders'],
      [:event_tree, 'root', 'miq_policy/_event_list'],
      [:condition_tree, 'root', 'miq_policy/_condition_folders'],
      [:action_tree, 'root', 'miq_policy/_action_list'],
      [:alert_profile_tree, 'root', 'miq_policy/_alert_profile_folders'],
      [:alert_tree, 'root', 'miq_policy/_alert_list'],
    ].each do |tree_sym, node, partial_name|
      it "renders #{partial_name} when #{tree_sym} tree #{node} node is selected" do
        session[:sandboxes] = {"miq_policy" => {:active_tree => tree_sym}}
        session[:settings] ||= {}

        post :tree_select, :params => { :id => node, :format => :js }
        expect(response).to render_template(partial_name)
        expect(response.status).to eq(200)
      end
    end
  end

  describe '#replace_right_cell' do
    it 'should replace policy_tree_div when replace_trees contains :policy' do
      allow(controller).to receive(:params).and_return(:action => 'whatever')
      controller.instance_eval { @sb = {:active_tree => :policy_tree} }
      allow(controller).to receive(:render).and_return(nil)
      presenter = ExplorerPresenter.new(:active_tree => :policy_tree)

      controller.send(:replace_right_cell, {:nodetype => 'root', :replace_trees => [:policy], :presenter => presenter})
      expect(presenter[:replace_partials]).to have_key('policy_tree_div')
    end

    it 'should not hide center toolbar while doing searches' do
      allow(controller).to receive(:params).and_return(:action => 'x_search_by_name')
      controller.instance_eval { @sb = {:active_tree => :action_tree} }
      controller.instance_eval { @edit = {:new => {:expression => {"???" => "???", :token => 1}}} }
      allow(controller).to receive(:render).and_return(nil)
      presenter = ExplorerPresenter.new(:active_tree => :action_tree)

      controller.send(:replace_right_cell, {:nodetype => 'root', :replace_trees => [:action], :presenter => presenter})
      expect(presenter[:set_visible_elements][:toolbar]).to be_truthy
    end

    it 'should change header' do
      allow(controller).to receive(:params).and_return(:action => 'whatever')
      controller.instance_eval { @sb = {:active_tree => :alert_profile_tree} }
      allow(controller).to receive(:render).and_return(nil)
      presenter = ExplorerPresenter.new(:active_tree => :alert_profile_tree)
      controller.send(:get_node_info, 'ap_xx-Storage')
      presenter[:right_cell_text] = 'foo'
      controller.send(:replace_right_cell, {:nodetype => 'xx', :replace_trees => [:alert_profile], :presenter => presenter})

      expect(presenter[:right_cell_text]).not_to equal('foo')
      expect(presenter[:right_cell_text]).to_not be_nil
    end
  end

  describe 'x_button' do
    before do
      ApplicationController.handle_exceptions = true
    end

    describe 'corresponding methods are called for allowed actions' do
      MiqPolicyController::POLICY_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
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
end
