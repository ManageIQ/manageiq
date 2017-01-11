describe OpsController do
  before(:each) do
    EvmSpecHelper.create_guid_miq_server_zone
    MiqRegion.seed
    stub_user(:features => :all)
  end

  describe 'x_button' do
    before do
      ApplicationController.handle_exceptions = true
    end

    describe 'corresponding methods are called for allowed actions' do
      OpsController::OPS_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
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

  it 'can view the db_settings tab' do
    ApplicationController.handle_exceptions = true

    session[:sandboxes] = {"ops" => {:active_tree => :vmdb_tree,
                                     :active_tab  => 'db_settings',
                                     :trees       => {:vmdb_tree => {:active_node => 'root'}}}}
    post :change_tab, :params => { :tab_id => 'db_settings', :format => :json }
  end

  it 'can view the db_connections tab' do
    ApplicationController.handle_exceptions = true

    session[:sandboxes] = {"ops" => {:active_tree => :vmdb_tree,
                                     :active_tab  => 'db_connections',
                                     :trees       => {:vmdb_tree => {:active_node => 'root'}}}}
    expect(controller).to receive(:head)
    post :change_tab, :params => { :tab_id => 'db_connections', :format => :json }
    expect(response.status).to eq(200)
  end

  describe 'rbac_user_edit' do
    let(:group) { FactoryGirl.create(:miq_group) }
    before do
      ApplicationController.handle_exceptions = true
    end

    it 'can add a user w/ group' do
      session[:edit] = {
        :key     => 'rbac_user_edit__new',
        :current => {},
        :new     => {
          :name      => 'test7',
          :userid    => 'test7',
          :email     => 'test7@foo.bar',
          :group     => group.id,
          :password  => 'test7',
          :verify    => 'test7',
        }
      }

      expect(controller).to receive(:replace_right_cell)
      get :rbac_user_edit, :params => { :button => 'add' }
    end

    it 'cannot add a user w/o matching passwords' do
      session[:edit] = {
        :key => 'rbac_user_edit__new',
        :new => {
          :name      => 'test7',
          :userid    => 'test7',
          :email     => 'test7@foo.bar',
          :group     => group.id,
          :password  => 'test7',
          :verify    => 'test8',
        }
      }

      expect(controller).to receive(:render_flash)
      get :rbac_user_edit, :params => { :button => 'add' }
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to eq("Password/Verify Password do not match")
      expect(flash_messages.first[:level]).to eq(:error)
    end

    it 'cannot add a user w/o group' do
      session[:edit] = {
        :key => 'rbac_user_edit__new',
        :new => {
          :name      => 'test7',
          :userid    => 'test7',
          :email     => 'test7@foo.bar',
          :group     => nil,
          :password  => 'test7',
          :verify    => 'test7',
        }
      }

      expect(controller).to receive(:render_flash)
      get :rbac_user_edit, :params => { :button => 'add' }
      flash_messages = assigns(:flash_array)
      expect(flash_messages.first[:message]).to eq("A User must be assigned to a Group")
      expect(flash_messages.first[:level]).to eq(:error)
    end
  end

  context "#db_backup" do
    it "posts db_backup action" do
      session[:settings] = {:default_search => ''}

      miq_schedule = FactoryGirl.create(:miq_schedule,
                                        :name        => "test_db_schedule",
                                        :description => "test_db_schedule_desc",
                                        :towhat      => "DatabaseBackup",
                                        :run_at      => {:start_time => "2015-04-19 00:00:00 UTC",
                                                         :tz         => "UTC",
                                                         :interval   => {:unit => "once", :value => ""}
                                                        })
      post :db_backup, :params => {
        :backup_schedule => miq_schedule.id,
        :uri             => "nfs://test_location",
        :uri_prefix      => "nfs",
        :action_typ      => "db_backup",
        :format          => :js
      }
      expect(response.status).to eq(200)
      expect(response.body).to_not be_empty
    end
  end

  context "#edit_changed?" do
    it "should set session[:changed] as false" do
      edit = {
        :new     => {:foo => 'bar'},
        :current => {:foo => 'bar'}
      }
      controller.instance_variable_set(:@edit, edit)
      controller.send(:edit_changed?)
      expect(session[:changed]).to eq(false)
    end

    it "should set session[:changed] as true" do
      edit = {
        :new     => {:foo => 'bar'},
        :current => {:foo => 'bar1'}
      }
      controller.instance_variable_set(:@edit, edit)
      controller.send(:edit_changed?)
      expect(session[:changed]).to eq(true)
    end

    it "should set session[:changed] as false when config is same" do
      vmdb = VMDB::Config.new("vmdb")
      # edit_changed? expects current to be VMDB::Config
      edit = {
        :new     => vmdb.config,
        :current => vmdb
      }
      controller.instance_variable_set(:@edit, edit)
      controller.send(:edit_changed?)
      expect(session[:changed]).to eq(false)
    end

    it "should set session[:changed] as true when config is sadifferentme" do
      edit = {
        :new     => {:workers => 2},
        :current => VMDB::Config.new("vmdb")
      }
      controller.instance_variable_set(:@edit, edit)
      controller.send(:edit_changed?)
      expect(session[:changed]).to eq(true)
    end
  end

  it "executes action schedule_edit" do
    schedule = FactoryGirl.create(:miq_schedule, :name => "test_schedule", :description => "old_schedule_desc")
    allow(controller).to receive(:get_node_info)
    allow(controller).to receive(:replace_right_cell)
    allow(controller).to receive(:render)

    post :schedule_edit, :params => {
      :id          => schedule.id,
      :button      => "save",
      :name        => "test_schedule",
      :description => "new_description",
      :action_typ  => "vm",
      :start_date  => "06/25/2015",
      :timer_typ   => "Once",
      :timer_value => ""
    }

    skip "https://github.com/rails/rails/issues/23881" if Gem::Requirement.new('< 5.0.0.beta4') === Rails.gem_version
    expect(response).to be_success

    audit_event = AuditEvent.where(:target_id => schedule.id).first
    expect(audit_event.attributes['message']).to include("description changed to new_description")
  end

  describe "#settings_update" do
    context "when the zone is changed" do
      it "updates the server's zone" do
        pending("temporary skip as something is broken with config revamp")

        server = MiqServer.first

        zone = FactoryGirl.create(:zone,
                                  :name        => "not the default",
                                  :description => "Not the Default Zone")

        current = double("current", :[] => {:server => {:zone => "default"}}).as_null_object
        new = double("new").as_null_object

        allow(new).to receive(:[]) do |arg|
          case arg
          when :authentication then {}
          when :server then {:zone => zone.name}
          else double.as_null_object
          end
        end

        edit = {:new  => new, :current => current}
        sb = {:active_tab => "settings_server", :selected_server_id => server.id}

        controller.instance_variable_set(:@edit, edit)
        controller.instance_variable_set(:@sb, sb)
        allow(controller).to receive(:settings_get_form_vars)
        allow(controller).to receive(:x_node).and_return(double("x_node").as_null_object)
        allow(controller).to receive(:settings_server_validate)
        allow(controller).to receive(:get_node_info)
        allow(controller).to receive(:replace_right_cell)

        # expect { post :settings_update, :id => "server", :button => "save" }
        expect { controller.send(:settings_update_save) }
          .to change { server.reload.zone }.to(zone)
      end
    end
  end
end

describe OpsController do
  before do
    MiqRegion.seed
    EvmSpecHelper.local_miq_server
    login_as FactoryGirl.create(:user, :features => "ops_rbac")
    allow(controller).to receive(:get_vmdb_config).and_return(:product => {})
  end

  context "#explorer" do
    it "sets correct active accordion value" do
      controller.instance_variable_set(:@sb, {})
      allow(controller).to receive(:get_node_info)
      expect(controller).to receive(:render)
      controller.send(:explorer)
      expect(response.status).to eq(200)
      expect(assigns(:sb)[:active_accord]).to eq(:rbac)
    end
  end

  context "#replace_explorer_trees" do
    it "build trees that are passed in and met other conditions" do
      controller.instance_variable_set(:@sb, {})
      allow(controller).to receive(:x_build_dyna_tree)
      replace_trees = [:settings, :diagnostics]
      presenter = ExplorerPresenter.new
      controller.send(:replace_explorer_trees, replace_trees, presenter)
      expect(response.status).to eq(200)
    end
  end

  context "Toolbar buttons render" do
    before do
      _guid, @miq_server, @zone = EvmSpecHelper.remote_guid_miq_server_zone
      allow(controller).to receive(:check_privileges).and_return(true)
      allow(controller).to receive(:assert_privileges).and_return(true)
      seed_session_trees('ops', :diagnostics_tree, "z-#{ApplicationRecord.compress_id(@zone.id)}")
      post :change_tab, :params => { :tab_id => "diagnostics_collect_logs" }
    end
    it "does not render toolbar buttons when edit is clicked" do
      post :x_button, :params => { :id => @miq_server.id, :pressed => 'log_depot_edit', :format => :js }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['setVisibility']['toolbar']).to be false
    end

    it "renders toolbar buttons when cancel is clicked" do
      allow(controller).to receive(:diagnostics_set_form_vars)
      post :x_button, :params => { :id => @miq_server.id, :pressed => 'log_depot_edit', :button => "cancel", :format => :js }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['setVisibility']['toolbar']).to be
    end

    it "renders toolbar buttons when save is clicked" do
      allow(controller).to receive(:diagnostics_set_form_vars)
      post :x_button, :params => { :id => @miq_server.id, :pressed => 'log_depot_edit', :button => "save", :format => :js }
      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)['setVisibility']['toolbar']).to be
    end
  end

  context "Import Tags and Import forms" do
    %w(settings_import settings_import_tags).each do |tab|
      render_views

      before do
        _guid, @miq_server, @zone = EvmSpecHelper.remote_guid_miq_server_zone
        allow(controller).to receive(:check_privileges).and_return(true)
        allow(controller).to receive(:assert_privileges).and_return(true)
        seed_session_trees('ops', :settings_tree, 'root')
        expect(controller).to receive(:render_to_string).with(any_args).twice
        post :change_tab, :params => {:tab_id => tab}
      end

      it "Apply button remains disabled with flash errors" do
        post :explorer, :params => {:flash_error => 'true',
                                    :flash_msg   => 'Error during upload',
                                    :no_refresh  => 'true'}
        expect(response.status).to eq(200)
        expect(response.body).to_not be_empty
        expect(response.body).to include("<div id='buttons_on' style='display: none;'>")
        expect(response.body).to include("<div id='buttons_off' style=''>\n<button name=\"button\" type=\"submit\" class=\"btn btn-primary disabled\">Apply</button>")
      end

      it "Apply button enabled when there are no flash errors" do
        controller.instance_variable_set(:@flash_array, [])
        post :explorer, :params => {:no_refresh => 'true'}
        expect(response.status).to eq(200)
        expect(response.body).to_not be_empty
        expect(response.body).to include("<div id='buttons_on' style=''>")
        expect(response.body).to include("<div id='buttons_off' style='display: none;'>\n<button name=\"button\" type=\"submit\" class=\"btn btn-primary disabled\">Apply</button>")
      end
    end
  end
end
