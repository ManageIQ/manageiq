require "spec_helper"

describe VmInfraController do
  render_views
  before :each do
    set_user_privileges
    FactoryGirl.create(:vmdb_database)
    EvmSpecHelper.create_guid_miq_server_zone
  end

  context "VMs & Templates #tree_select" do
    it "renders VM and Template list for vandt_tree root node" do
      FactoryGirl.create(:vm_vmware)

      session[:settings] = {}
      session[:sandboxes] = {
        "vm_infra" => {
          :trees => {
            :vandt_tree => {}
          },
          :active_tree => :vandt_tree
        }
      }
      post :tree_select, :id => 'root', :format => :js

      response.should render_template('layouts/gtl/_list')
      expect(response.status).to eq(200)
    end
  end

  context "VMs #tree_select" do
    it "renders list with VMS for vms_filter_tree root node" do
      FactoryGirl.create(:vm_vmware)

      session[:settings] = {}
      session[:sandboxes] = {
        "vm_infra" => {
          :trees => {
            :vms_filter_tree => {}
          },
          :active_tree => :vms_filter_tree
        }
      }
      post :tree_select, :id => 'root', :format => :js

      response.should render_template('layouts/gtl/_list')
      expect(response.status).to eq(200)
    end
  end

  context "Templates #tree_select" do
    it "renders list with templates for templates_filter_tree root node" do
      FactoryGirl.create(:template_vmware)

      session[:settings] = {}
      session[:sandboxes] = {
        "vm_infra" => {
          :trees => {
            :templates_filter_tree => {}
          },
          :active_tree => :templates_filter_tree
        }
      }
      post :tree_select, :id => 'root', :format => :js

      response.should render_template('layouts/gtl/_list')
      expect(response.status).to eq(200)
    end
  end
end
