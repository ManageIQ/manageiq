describe "ops/_all_tabs.html.haml" do
  context "diagnostics tree loads correct tabs based on x_node" do
    let(:server) { EvmSpecHelper.local_miq_server }

    before do
      allow(MiqServer).to receive(:my_server).and_return(server)
    end

    it "should render tabs for current server" do
      assign(:sb,
             :active_tab         => "diagnostics_roles_servers",
             :active_tree        => :diagnostics_tree,
             :selected_server_id => server.id,
             :trees              => {:diagnostics_tree => {:active_node => "svr-#{server.id}"}})
      assign(:selected_server, server)
      render :partial => "ops/all_tabs"
      expect(response).to render_template(:partial => "ops/_diagnostics_timelines_tab")
      expect(response).to render_template(:partial => "ops/_diagnostics_production_log_tab")
    end

    it "should render tabs only for non-current server" do
      assign(:selected_server, FactoryGirl.create(:miq_server))
      assign(:sb,
             :active_tab         => "diagnostics_roles_servers",
             :active_tree        => :diagnostics_tree,
             :selected_server_id => "1",
             :trees              => {:diagnostics_tree => {:active_node => "svr-2"}})
      render :partial => "ops/all_tabs"
      expect(response).to render_template(:partial => "ops/_diagnostics_timelines_tab")
      expect(response).not_to render_template(:partial => "ops/_diagnostics_production_log_tab")
    end

    it "should render tabs only specific to zone node" do
      assign(:selected_server, FactoryGirl.create(:miq_server))
      assign(:sb,
             :active_tab         => "diagnostics_roles_servers",
             :active_tree        => :diagnostics_tree,
             :selected_server_id => "1",
             :trees              => {:diagnostics_tree => {:active_node => "z-2"}})
      render :partial => "ops/all_tabs"
      expect(response).to render_template(:partial => "ops/_diagnostics_roles_servers_tab")
      expect(response).to render_template(:partial => "ops/_diagnostics_cu_repair_tab")
    end
  end
end
