require "spec_helper"

describe VmCloudController do
  render_views
  before :each do
    set_user_privileges
    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone
    expect(MiqServer.my_guid).to be
    expect(MiqServer.my_server).to be

    session[:userid] = User.current_user.userid
  end

  context "#tree_select" do
    [
      %w(Instances instances_tree),
      %w(Images images_tree),
      %w(Instances instances_filter_tree),
      %w(Images images_filter_tree)
    ].each do |elements, tree|
      it "renders list of #{elements} for #{tree} root node" do
        FactoryGirl.create(:vm_openstack)
        FactoryGirl.create(:template_openstack)

        session[:settings] = {}
        seed_session_trees('vm_cloud', tree.to_sym)

        post :tree_select, :id => 'root', :format => :js

        response.should render_template('layouts/gtl/_list')
        expect(response.status).to eq(200)
      end
    end

    it "renders Instance details for Instance node" do
      instance = FactoryGirl.create(:vm_openstack)

      session[:settings] = {}
      seed_session_trees('vm_cloud', 'instances_tree')

      post :tree_select, :id => "v-#{instance.compressed_id}", :format => :js

      response.should render_template('vm_cloud/_main')
      response.should render_template('shared/summary/_textual_tags')
      expect(response.status).to eq(200)
    end
  end
end
