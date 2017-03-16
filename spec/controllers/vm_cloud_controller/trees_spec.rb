describe VmCloudController do
  render_views
  before :each do
    stub_user(:features => :all)
    EvmSpecHelper.create_guid_miq_server_zone
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

        post :tree_select, :params => { :id => 'root', :format => :js }

        expect(response).to render_template('layouts/gtl/_list')
        expect(response.status).to eq(200)
      end
    end

    [
      %w(vm_openstack Openstack),
      %w(vm_azure Azure),
      %w(vm_google Google),
      %w(vm_amazon Amazon)
    ].each do |instance, name|
      it "renders Instance details for #{name} node" do
        instance = FactoryGirl.create(instance.to_sym, :with_provider)

        session[:settings] = {}
        seed_session_trees('vm_cloud', 'instances_tree')

        post :tree_select, :params => { :id => "v-#{instance.compressed_id}", :format => :js }

        expect(response).to render_template('vm_cloud/_main')
        expect(response).to render_template('shared/summary/_textual_tags')
        expect(response.status).to eq(200)
      end
    end
  end
end
