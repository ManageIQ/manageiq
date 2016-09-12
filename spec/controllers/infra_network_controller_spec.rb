describe InfraNetworkingController do
  include CompressedIds

  let(:switch) { FactoryGirl.create(:switch, :name => 'test_switch1', :shared => 'true') }
  let(:host) { FactoryGirl.create(:host, :name => 'test_host1') }
  let(:ems_vmware) { FactoryGirl.create(:ems_vmware, :name => 'test_vmware') }
  let(:cluster) { FactoryGirl.create(:cluster, :name => 'test_cluster') }
  before { stub_user(:features => :all) }

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
          FactoryGirl.create(:switch, :name => 'test_switch' % i, :shared => true)
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
