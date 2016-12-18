shared_examples "logs_collect" do |type|
  let(:klass) { type.classify.constantize }
  let(:zone) { double("Zone", :name => "foo") }
  let(:server) { double("MiqServer", :logon_status => :ready, :id => 1, :my_zone => zone) }
  before do
    sb_hash = {
      :trees            => {:diagnostics_tree => {:active_node => active_node}},
      :active_tree      => :diagnostics_tree,
      :diag_selected_id => instance_variable_get("@#{type}").id,
      :active_tab       => "diagnostics_roles_servers"
    }
    controller.instance_variable_set(:@sb, sb_hash)
    allow(MiqServer).to receive(:my_server).and_return(server)
  end

  it "not running" do
    allow_any_instance_of(MiqServer).to receive(:status).and_return("stopped")

    expect(controller).to receive(:replace_right_cell).with(:nodetype => active_node)

    controller.send(:logs_collect)

    expect(assigns(:flash_array).first[:message]).to include("requires a started server")
  end

  it "collection already in progress" do
    expect_any_instance_of(klass).to receive(:log_collection_active_recently?).and_return(true)
    expect(controller).to receive(:replace_right_cell).with(:nodetype => active_node)

    controller.send(:logs_collect)

    expect(assigns(:flash_array).first[:message]).to include("already in progress")
  end

  context "nothing preventing collection" do
    it "succeeds" do
      expect_any_instance_of(klass).to receive(:log_collection_active_recently?).and_return(false)
      expect_any_instance_of(klass).to receive(:synchronize_logs).with(user.userid, :context => klass.name)
      expect(controller).to receive(:replace_right_cell).with(:nodetype => active_node)

      controller.send(:logs_collect)

      expect(assigns(:flash_array).first[:message]).to include("has been initiated")
    end

    it "collection raises and error" do
      expect_any_instance_of(klass).to receive(:log_collection_active_recently?).and_return(false)
      expect_any_instance_of(klass).to receive(:synchronize_logs).and_raise(StandardError)
      expect(controller).to receive(:replace_right_cell).with(:nodetype => active_node)

      controller.send(:logs_collect)

      expect(assigns(:flash_array).first[:message]).to include("Log collection error returned")
    end
  end
end

describe OpsController do
  render_views
  context "#tree_select" do
    it "renders zone list for diagnostics_tree root node" do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      MiqRegion.seed

      session[:sandboxes] = {"ops" => {:active_tree => :diagnostics_tree}}
      post :tree_select, :params => { :id => 'root', :format => :js }

      expect(response).to render_template('ops/_diagnostics_zones_tab')
      expect(response.status).to eq(200)
    end
  end

  context "#log_collection_form_fields" do
    it "renders log_collection_form_fields" do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      MiqRegion.seed

      _guid, @miq_server, @zone = EvmSpecHelper.remote_guid_miq_server_zone
      file_depot = FileDepotNfs.create(:name => "abc", :uri => "nfs://abc")
      @miq_server.update_attributes(:log_file_depot_id => file_depot.id)

      session[:sandboxes] = {"ops" => {:active_tree        => :diagnostics_tree,
                                       :selected_typ       => "miq_server",
                                       :selected_server_id => @miq_server.id}}
      post :tree_select, :params => { :id => 'root', :format => :js }
      get :log_collection_form_fields, :params => { :id => @miq_server.id }
      expect(response.status).to eq(200)
    end
  end

  context "#set_credentials" do
    it "uses params[:log_password] to set the creds hash if it exists" do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      MiqRegion.seed

      _guid, @miq_server, @zone = EvmSpecHelper.remote_guid_miq_server_zone
      controller.instance_variable_set(:@record, @miq_server)
      controller.instance_variable_set(:@_params,
                                       :log_userid   => "default_userid",
                                       :log_password => "default_password2")
      default_creds = {:userid => "default_userid", :password => "default_password2"}
      expect(controller.send(:set_credentials)).to include(:default => default_creds)
    end

    it "uses stored password to set the creds hash" do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      MiqRegion.seed

      _guid, @miq_server, @zone = EvmSpecHelper.remote_guid_miq_server_zone
      file_depot = FileDepotSmb.create(:name => "abc", :uri => "smb://abc")
      expect(@miq_server).to receive(:log_file_depot).and_return(file_depot)
      expect(file_depot).to receive(:authentication_password).and_return('default_password')
      controller.instance_variable_set(:@record, @miq_server)
      controller.instance_variable_set(:@_params,
                                       :log_userid => "default_userid")
      default_creds = {:userid => "default_userid", :password => "default_password"}
      expect(controller.send(:set_credentials)).to include(:default => default_creds)
    end
  end

  context "::Diagnostics" do
    let!(:user) { stub_user(:features => :all) }
    before do
      EvmSpecHelper.local_miq_server
      MiqRegion.seed
      _guid, @miq_server, @zone = EvmSpecHelper.remote_guid_miq_server_zone
      @miq_server_to_delete = FactoryGirl.create(:miq_server)
      @miq_server_to_delete.last_heartbeat -= 20.minutes
      @miq_server_to_delete.save
    end

    it "#restart_server returns successful message" do
      expect(@miq_server).to receive(:restart_queue).and_return(true)

      expect(MiqServer).to receive(:find).and_return(@miq_server)

      post :restart_server

      expect(response.body).to include("flash_msg_div")
      expect(response.body).to include("%{product} Appliance restart initiated successfully" % {:product => I18n.t('product.name')})
    end

    it "#delete_server returns successful message" do
      sb_hash = {
        :trees            => {:diagnostics_tree => {:active_node => "z-#{@zone.id}"}},
        :active_tree      => :diagnostics_tree,
        :diag_selected_id => @miq_server.id,
        :active_tab       => "diagnostics_roles_servers"
      }
      @miq_server.update_attributes(:status => "stopped")
      allow(controller).to receive(:build_server_tree)
      controller.instance_variable_set(:@sb, sb_hash)

      expect(controller).to receive(:render)

      controller.send(:delete_server)

      flash_message = assigns(:flash_array).first
      expect(flash_message[:message]).to include("Delete successful")
      expect(flash_message[:level]).to be(:success)
    end

    describe '#delete_server' do
      context "server does exist" do
        it 'deletes server and refreshes screen' do
          server = FactoryGirl.create(:miq_server, :zone => @zone)
          sb_hash = {
            :trees            => {:diagnostics_tree => {:active_node => "z-#{@zone.id}"}},
            :active_tree      => :diagnostics_tree,
            :diag_selected_id => @miq_server_to_delete.id,
            :active_tab       => "diagnostics_roles_servers"
          }
          @server_role = FactoryGirl.create(
            :server_role,
            :name              => "smartproxy",
            :description       => "SmartProxy",
            :max_concurrent    => 1,
            :external_failover => false,
            :role_scope        => "zone"
          )
          @assigned_server_role = FactoryGirl.create(
            :assigned_server_role,
            :miq_server_id  => server.id,
            :server_role_id => @server_role.id,
            :active         => true,
            :priority       => 1
          )
          controller.instance_variable_set(:@sb, sb_hash)
          controller.instance_variable_set(:@_params, :pressed => "zone_delete_server")
          expect(controller).to receive :render

          controller.send(:delete_server)

          flash_array = assigns(:flash_array)

          diag_selected_id = controller.instance_variable_get(:@sb)[:diag_selected_id]
          expect(diag_selected_id).not_to eq(@miq_server_to_delete.id)
          expect(flash_array.size).to eq 1
          expect(flash_array.first[:message]).to match(/Server .*: Delete successful/)
        end
      end

      context ':diag_selected_id is not set' do
        it 'should set the flash saying that server no longer exists' do
          controller.instance_variable_set(:@sb, {})
          expect(controller).to receive :refresh_screen

          controller.send(:delete_server)

          expect(assigns(:flash_array)).to eq [
            {
              :message => 'EVM Server no longer exists',
              :level   => :error
            }
          ]
        end
      end

      context "server doesn't exist" do
        it 'should set the flash saying that server no longer exists' do
          controller.instance_variable_set(:@sb, :diag_selected_id => -100500)
          expect(controller).to receive :refresh_screen

          controller.send(:delete_server)

          expect(assigns(:flash_array)).to eq [
            {
              :message => 'The selected EVM Server was deleted',
              :level   => :success
            }
          ]
        end
      end

      context "server does exist, but something goes wrong during deletion" do
        it 'should set the flash saying that server no longer exists' do
          controller.instance_variable_set(:@sb, { :diag_selected_id => @miq_server.id })
          expect(controller).to receive :refresh_screen
          expect_any_instance_of(MiqServer).to receive(:destroy).and_raise 'boom'

          controller.send(:delete_server)

          flash_array = assigns(:flash_array)
          expect(flash_array.size).to eq 1

          expect(flash_array.first[:level]).to eq :error
          expect(flash_array.first[:message]).to match /Server .*: Error during 'destroy': boom/
        end
      end

      context "#role_start" do
        before do
          assigned_server_role = FactoryGirl.create(
            :assigned_server_role,
            :miq_server_id  => 1,
            :server_role_id => 1,
            :active         => false,
            :priority       => 1
          )
          sb_hash = {
            :trees            => {:diagnostics_tree => {:active_node => "root"}},
            :active_tree      => :diagnostics_tree,
            :diag_selected_id => assigned_server_role.id,
            :active_tab       => "diagnostics_roles_servers"
          }

          controller.instance_variable_set(:@sb, sb_hash)
          controller.instance_variable_set(:@_params, :pressed => "role_start", :action => "x_button")
          expect(controller).to receive :build_server_tree
          expect(controller).to receive(:render)
        end

        it 'sets selected_server to selected region record in diagnostics tree' do
          controller.send(:role_start)
          expect(assigns(:selected_server)).to eq(MiqRegion.my_region)
        end

        it 'sets selected_server to selected zone record in diagnostics tree' do
          controller.x_node = "z-#{@zone.id}"
          controller.send(:role_start)
          expect(assigns(:selected_server)).to eq(@zone)
        end
      end
    end

    context "#logs_collect" do
      context "Server" do
        let(:active_node) { "svr-#{@miq_server.id}" }
        include_examples "logs_collect", "miq_server"
      end
      context "Zone" do
        let(:active_node) { "z-#{@zone.id}" }
        include_examples "logs_collect", "zone"
      end
    end

    context "#log_depot_edit" do
      it "renders validate button" do
        server_id = @miq_server.id
        sb_hash = {
          :selected_server_id => server_id,
          :selected_typ       => "miq_server"
        }
        edit = {
          :new => {},
          :key => "logdepot_edit__#{server_id}"
        }
        session[:edit] = edit
        controller.instance_variable_set(:@sb, sb_hash)
        allow(controller).to receive(:set_credentials)
          .and_return(:default => {:userid => "testuser", :password => 'password'})
        controller.instance_variable_set(:@_params,
                                         :log_userid => "default_user",
                                         :button     => "validate",
                                         :id         => server_id)
        expect(controller).to receive(:render)
        expect(response.status).to eq(200)
        controller.send(:log_depot_edit)
      end
    end
  end
end
