describe VmInfraController do
  render_views
  before :each do
    set_user_privileges
    EvmSpecHelper.create_guid_miq_server_zone
  end

  context "VMs & Templates #tree_select" do
    it "renders list Archived nodes in VMs & Templates tree" do
      FactoryGirl.create(:vm_vmware)

      session[:settings] = {}
      seed_session_trees('vm_infra', :vandt_tree)

      post :tree_select, :params => { :id => 'xx-arch', :format => :js }

      expect(response).to render_template('layouts/gtl/_list')
      expect(response.status).to eq(200)
    end
  end

  context "#tree_select" do
    [
      ['Vms & Templates', 'vandt_tree'],
      %w(VMS vms_filter_tree),
      %w(Templates templates_filter_tree),
    ].each do |elements, tree|
      it "renders list of #{elements} for #{tree} root node" do
        FactoryGirl.create(:vm_vmware)
        FactoryGirl.create(:template_vmware)

        session[:settings] = {}
        seed_session_trees('vm_infra', tree.to_sym)

        post :tree_select, :params => { :id => 'root', :format => :js }

        expect(response).to render_template('layouts/gtl/_list')
        expect(response.status).to eq(200)
      end
    end

    it "renders VM details for VM node" do
      vm = FactoryGirl.create(:vm_vmware)

      session[:settings] = {}
      seed_session_trees('vm_infra', 'vandt_tree')

      post :tree_select, :params => { :id => "v-#{vm.compressed_id}", :format => :js }

      expect(response).to render_template('vm_common/_main')
      expect(response).to render_template('shared/summary/_textual_tags')
      expect(response.status).to eq(200)
    end

    it "renders Template details for Template node" do
      template = FactoryGirl.create(:template_vmware)

      session[:settings] = {}
      seed_session_trees('vm_infra', 'vandt_tree')

      post :tree_select, :params => { :id => "t-#{template.compressed_id}", :format => :js }

      expect(response).to render_template('vm_common/_main')
      expect(response).to render_template('shared/summary/_textual_tags')
      expect(response.status).to eq(200)
    end
  end
end
