require "spec_helper"
include UiConstants

shared_examples "logs_collect" do |type|
  let(:klass) { type.classify.constantize }
  before do
    sb_hash = {
      :trees            => {:diagnostics_tree => {:active_node => active_node}},
      :active_tree      => :diagnostics_tree,
      :diag_selected_id => instance_variable_get("@#{type}").id,
      :active_tab       => "diagnostics_roles_servers"
    }
    controller.instance_variable_set(:@sb, sb_hash)
    controller.instance_variable_set(:@temp, {})
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
      klass.any_instance.should_receive(:synchronize_logs).with(nil, {})
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
  context "::Diagnostics" do
    before do
      set_user_privileges
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
      controller.instance_variable_set(:@temp, {})
      controller.instance_variable_set(:@sb, sb_hash)

      controller.should_receive(:render)

      controller.send(:delete_server)

      flash_message = assigns(:flash_array).first
      flash_message[:message].should include("Delete successful")
      flash_message[:level].should be(:info)
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
  end
end
