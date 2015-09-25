require "spec_helper"

describe OpsController do
  before(:each) do
    EvmSpecHelper.create_guid_miq_server_zone
    MiqRegion.seed
    set_user_privileges
  end

  describe 'x_button' do
    describe 'corresponding methods are called for allowed actions' do
      OpsController::OPS_X_BUTTON_ALLOWED_ACTIONS.each_pair do |action_name, method|
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

  it 'can view the db_settings tab' do
    session[:sandboxes] = {"ops" => {:active_tree => :vmdb_tree,
                                     :active_tab  => 'db_settings',
                                     :trees       => {:vmdb_tree => {:active_node => 'root'}}}}
    session[:settings] = {:views => {}, :perpage => {:list => 10}}
    post :change_tab, :tab_id => 'db_settings', :format => :json
  end

  it 'can view the db_connections tab' do
    FactoryGirl.create(:vmdb_database)
    session[:sandboxes] = {"ops" => {:active_tree => :vmdb_tree,
                                     :active_tab  => 'db_connections',
                                     :trees       => {:vmdb_tree => {:active_node => 'root'}}}}
    session[:settings] = {:views => {}, :perpage => {:list => 10}}
    controller.should_receive(:render)
    post :change_tab, :tab_id => 'db_connections', :format => :json
    expect(response.status).to eq(200)
  end

  #  def rbac_user_edit
  #
  # def rbac_user_set_record_vars(user)
  describe 'rbac_user_edit' do
    it 'can add a user w/ group' do
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      session[:edit] = {
        :key => 'rbac_user_edit__new',
        :current => {},
        :new => {
          :name      => 'test7',
          :userid    => 'test7',
          :email     => 'test7@foo.bar',
          :group     => 'test_group',
          :password  => 'test7',
          :password2 => 'test7',
        }
      }

      controller.should_receive(:replace_right_cell)
      get :rbac_user_edit, :button => 'add'
    end

    it 'cannot add a user w/o matching passwords' do
      session[:settings] = {}
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      session[:edit] = {
        :key => 'rbac_user_edit__new',
        :new => {
          :name      => 'test7',
          :userid    => 'test7',
          :email     => 'test7@foo.bar',
          :group     => 'test_group',
          :password  => 'test7',
          :password2 => 'test8',
        }
      }

      controller.should_receive(:render_flash)
      get :rbac_user_edit, :button => 'add'
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should == "Password/Verify Password do not match"
      flash_messages.first[:level].should == :error
    end

    it 'cannot add a user w/o group' do
      session[:settings] = {}
      session[:settings] = {:views => {}, :perpage => {:list => 10}}
      session[:edit] = {
        :key => 'rbac_user_edit__new',
        :new => {
          :name      => 'test7',
          :userid    => 'test7',
          :email     => 'test7@foo.bar',
          :group     => nil,
          :password  => 'test7',
          :password2 => 'test7',
        }
      }

      controller.should_receive(:render_flash)
      get :rbac_user_edit, :button => 'add'
      flash_messages = assigns(:flash_array)
      flash_messages.first[:message].should == "A User must be assigned to a Group"
      flash_messages.first[:level].should == :error
    end
  end

  context "#db_backup" do
    it "posts db_backup action" do
      session[:settings] = {:default_search => '',
                            :views          => {},
                            :perpage        => {:list => 10}}

      miq_schedule = FactoryGirl.create(:miq_schedule,
                                        :name        => "test_db_schedule",
                                        :description => "test_db_schedule_desc",
                                        :towhat      => "DatabaseBackup",
                                        :run_at      => {:start_time => "2015-04-19 00:00:00 UTC",
                                                         :tz         => "UTC",
                                                         :interval   => {:unit => "once", :value => ""}
                                                        })
      post :db_backup,
           :backup_schedule => miq_schedule.id,
           :uri             => "nfs://test_location",
           :uri_prefix      => "nfs",
           :action_typ      => "db_backup",
           :format          => :js
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
      session[:changed].should eq(false)
    end

    it "should set session[:changed] as true" do
      edit = {
        :new     => {:foo => 'bar'},
        :current => {:foo => 'bar1'}
      }
      controller.instance_variable_set(:@edit, edit)
      controller.send(:edit_changed?)
      session[:changed].should eq(true)
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
      session[:changed].should eq(false)
    end

    it "should set session[:changed] as true when config is sadifferentme" do
      edit = {
        :new     => {:workers => 2},
        :current => VMDB::Config.new("vmdb")
      }
      controller.instance_variable_set(:@edit, edit)
      controller.send(:edit_changed?)
      session[:changed].should eq(true)
    end

  end

  it "executes action schedule_edit" do
    schedule = FactoryGirl.create(:miq_schedule, :name => "test_schedule", :description => "old_schedule_desc")
    controller.stub(:get_node_info)
    controller.stub(:replace_right_cell)
    controller.stub(:render)

    post :schedule_edit,
         :id          => schedule.id,
         :button      => "save",
         :name        => "test_schedule",
         :description => "new_description",
         :action_typ  => "vm",
         :start_date  => "06/25/2015",
         :timer_typ   => "Once",
         :timer_value => ""

    expect(response.status).to eq(200)

    audit_event = AuditEvent.where(:target_id => schedule.id).first
    expect(audit_event.attributes['message']).to include("description changed to new_description")
  end

  describe "#settings_update" do
    context "when the zone is changed" do
      it "updates the server's zone" do
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
    EvmSpecHelper.seed_specific_product_features("ops_rbac")
    feature = MiqProductFeature.find_all_by_identifier("ops_rbac")
    @test_user_role  = FactoryGirl.create(:miq_user_role,
                                          :name                 => "test_user_role",
                                          :miq_product_features => feature)
    test_user_group = FactoryGirl.create(:miq_group, :miq_user_role => @test_user_role)
    login_as FactoryGirl.create(:user, :name => 'test_user', :miq_groups => [test_user_group])
    controller.stub(:get_vmdb_config).and_return(:product => {})
  end

  context "#explorer" do
    it "sets correct active accordion value" do
      controller.instance_variable_set(:@sb, {})
      controller.stub(:get_node_info)
      controller.should_receive(:render)
      controller.send(:explorer)
      expect(response.status).to eq(200)
      assigns(:sb)[:active_accord].should eq(:rbac)
    end
  end

  context "#replace_explorer_trees" do
    it "build trees that are passed in and met other conditions" do
      controller.instance_variable_set(:@sb, {})
      controller.stub(:x_build_dyna_tree)
      r = proc { |opts| opts }
      replace_trees = [:settings, :diagnostics, :analytics]
      presenter = ExplorerPresenter.new
      controller.send(:replace_explorer_trees, replace_trees, presenter, r)
      expect(response.status).to eq(200)
    end
  end
end
