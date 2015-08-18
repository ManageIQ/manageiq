require "spec_helper"
include UiConstants

shared_examples "logs_collect" do |type|
  let(:klass) { type.classify.constantize }
  let(:zone) { active_record_instance_double("Zone", :name => "foo") }
  let(:server) { active_record_instance_double("MiqServer", :logon_status => :ready, :id => 1, :my_zone => zone) }
  before do
    sb_hash = {
      :trees            => {:diagnostics_tree => {:active_node => active_node}},
      :active_tree      => :diagnostics_tree,
      :diag_selected_id => instance_variable_get("@#{type}").id,
      :active_tab       => "diagnostics_roles_servers"
    }
    controller.instance_variable_set(:@sb, sb_hash)
    MiqServer.stub(:my_server).with(true).and_return(server)
  end

  it "not running" do
    MiqServer.any_instance.stub(:status).and_return("stopped")

    controller.should_receive(:replace_right_cell).with(active_node)

    controller.send(:logs_collect)

    expect(assigns(:flash_array).first[:message]).to include("requires a started server")
  end

  it "collection already in progress" do
    klass.any_instance.should_receive(:log_collection_active_recently?).and_return(true)
    controller.should_receive(:replace_right_cell).with(active_node)

    controller.send(:logs_collect)

    expect(assigns(:flash_array).first[:message]).to include("already in progress")
  end

  context "nothing preventing collection" do
    it "succeeds" do
      klass.any_instance.should_receive(:log_collection_active_recently?).and_return(false)
      klass.any_instance.should_receive(:synchronize_logs).with(user.userid, {})
      controller.should_receive(:replace_right_cell).with(active_node)

      controller.send(:logs_collect)

      expect(assigns(:flash_array).first[:message]).to include("has been initiated")
    end

    it "collection raises and error" do
      klass.any_instance.should_receive(:log_collection_active_recently?).and_return(false)
      klass.any_instance.should_receive(:synchronize_logs).and_raise(StandardError)
      controller.should_receive(:replace_right_cell).with(active_node)

      controller.send(:logs_collect)

      expect(assigns(:flash_array).first[:message]).to include("Log collection error returned")
    end
  end
end

describe OpsController do
  render_views
  context "#tree_select" do
    it "renders zone list for diagnostics_tree root node" do
      set_user_privileges
      FactoryGirl.create(:vmdb_database)
      EvmSpecHelper.create_guid_miq_server_zone

      session[:sandboxes] = { "ops" => { :active_tree => :diagnostics_tree } }
      post :tree_select, :id => 'root', :format => :js

      response.should render_template('ops/_diagnostics_zones_tab')
      expect(response.status).to eq(200)
    end
  end

  context "::Diagnostics" do
    let(:user) { FactoryGirl.create(:user) }
    before do
      set_user_privileges user
      _guid, @miq_server, @zone = EvmSpecHelper.remote_guid_miq_server_zone
    end

    it "#restart_server returns successful message" do
      @miq_server.should_receive(:restart_queue).and_return(true)

      MiqServer.should_receive(:find).and_return(@miq_server)

      post :restart_server

      response.body.should include("flash_msg_div")
      response.body.should include("CFME Appliance restart initiated successfully")
    end

    it "#delete_server returns successful message" do
      sb_hash = {
        :trees            => {:diagnostics_tree => {:active_node => "z-#{@zone.id}"}},
        :active_tree      => :diagnostics_tree,
        :diag_selected_id => @miq_server.id,
        :active_tab       => "diagnostics_roles_servers"
      }
      @miq_server.update_attributes(:status => "stopped")
      controller.stub(:build_server_tree)
      controller.instance_variable_set(:@sb, sb_hash)

      controller.should_receive(:render)

      controller.send(:delete_server)

      flash_message = assigns(:flash_array).first
      flash_message[:message].should include("Delete successful")
      flash_message[:level].should be(:success)
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
        controller.instance_variable_set(:@_params, :button => "validate", :id => server_id)
        controller.should_receive(:render)
        expect(response.status).to eq(200)
        controller.send(:log_depot_edit)
      end
    end
  end
end
