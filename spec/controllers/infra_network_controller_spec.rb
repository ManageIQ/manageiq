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
        expect(response.body).to include("<li>\n<span>\n6-7 of 7\n<input name='limitstart' type='hidden' value='0'>\n</span>\n</li>")
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

  context "#tags_edit" do
    let!(:user) { stub_user(:features => :all) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ds = FactoryGirl.create(:switch, :name => "testSwitch")
      allow(@ds).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@ds).and_return([@tag1, @tag2])
      session[:tag_db] = "Switch"
      edit = {
        :key        => "Switch_edit_tags__#{@ds.id}",
        :tagging    => "Switch",
        :object_ids => [@ds.id],
        :current    => {:assignments => []},
        :new        => {:assignments => [@tag1.id, @tag2.id]}
      }
      session[:edit] = edit
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "builds tagging screen" do
      post :button, :params => { :pressed => "infra_networking_tag", :format => :js, :id => @ds.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "infra_networking/show/#{@ds.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "cancel", :format => :js, :id => @ds.id }
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "infra_networking/show/#{@ds.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "save", :format => :js, :id => @ds.id }
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end
end
