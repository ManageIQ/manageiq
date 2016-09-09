describe InfraNetworkingController do
  include CompressedIds

  let(:switch) { FactoryGirl.create(:switch, {:name => 'test_switch1', :shared => 'true'}) }
  let(:host) { FactoryGirl.create(:host, :name => 'test_host1') }
  let(:ems_vmware) { FactoryGirl.create(:ems_vmware, :name => 'test_vmware') }
  let(:cluster) { FactoryGirl.create(:cluster, :name => 'test_cluster') }
  before { stub_user(:features => :all) }

  context "#button" do
    it "when Host Analyze then Check Compliance is pressed" do
      controller.instance_variable_set(:@_params, :pressed => "host_analyze_check_compliance")
      allow(controller).to receive(:show)
      expect(controller).to receive(:analyze_check_compliance_hosts)
      controller.button
      expect(controller.send(:flash_errors?)).not_to be_truthy
    end

    {"host_standby"  => "Enter Standby Mode",
     "host_shutdown" => "Shut Down",
     "host_reboot"   => "Restart",
     "host_start"    => "Power On",
     "host_stop"     => "Power Off",
     "host_reset"    => "Reset"
    }.each do |button, description|
      it "when Host #{description} button is pressed" do
        login_as FactoryGirl.create(:user, :features => button)

        host = FactoryGirl.create(:host)
        command = button.split('_', 2)[1]
        allow_any_instance_of(Host).to receive(:is_available?).with(command).and_return(true)

        controller.instance_variable_set(:@_params, :pressed => button, :miq_grid_checks => "#{host.id}")
        controller.instance_variable_set(:@lastaction, "show_list")
        allow(controller).to receive(:show_list)
        controller.button
        flash_messages = assigns(:flash_array)
        expect(flash_messages.first[:message]).to include("successfully initiated")
        expect(flash_messages.first[:level]).to eq(:success)
      end
    end
  end

  context 'render_views' do
    render_views

    context '#explorer' do
      before do
        session[:settings] = {:views => {}, :perpage => {:list => 5}}
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it 'can render the explorer' do
        session[:sb] = {:active_accord => :infra_networking_accord}
        seed_session_trees('switch', :infra_networking_tree, 'root')
        get :explorer
        expect(response.status).to eq(200)
        expect(response.body).to_not be_empty
      end

      it 'shows a switch in the list' do
        switch
        session[:sb] = {:active_accord => :infra_networking_accord}
        seed_session_trees('switch', :infra_networking_tree, 'root')

        get :explorer
        expect(response.body).to match(%r({"text":\s*"test_switch1"}))
      end

      it 'can render the second page of switches' do
        7.times do |i|
          FactoryGirl.create(:switch, {:name => 'test_switch' % i, :shared => true})
        end
        session[:sb] = {:active_accord => :infra_networking_accord}
        seed_session_trees('switch', :infra_networking_tree, 'root')
        allow(controller).to receive(:current_page).and_return(2)
        get :explorer, :params => {:page => '2'}
        expect(response.status).to eq(200)
        expect(response.body).to include("<li>\n<span>\nShowing 6-7 of 7 items\n<input name='limitstart' type='hidden' value='0'>\n</span>\n</li>")
      end
    end

    context "#tree_select" do
      before do
        switch
      end

      [
        ['All Distributed Switches', 'infra_networking_tree'],
      ].each do |elements, tree|
        it "renders list of #{elements} for #{tree} root node" do
          session[:settings] = {}
          seed_session_trees('infra_networking', tree.to_sym)

          post :tree_select, :params => { :id => 'root', :format => :js }
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
