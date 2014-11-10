require 'spec_helper'
require 'routing/shared_examples'

describe 'routes for VmInfra' do
  let(:controller_name) { 'vm_infra' }

  it_behaves_like 'A controller that has advanced search routes'
  it_behaves_like "A controller that has column width routes"
  it_behaves_like 'A controller that has compare routes'
  it_behaves_like 'A controller that has download_data routes'
  it_behaves_like 'A controller that has explorer routes'
  it_behaves_like 'A controller that has performance routes'
  it_behaves_like 'A controller that has policy protect routes'
  it_behaves_like 'A controller that has tagging routes'
  it_behaves_like 'A controller that has timeline routes'
  it_behaves_like 'A controller that has vm_common routes'

  describe '#dialog_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/dialog_field_changed")).to route_to("#{controller_name}#dialog_field_changed")
    end
  end

  describe '#dialog_form_button_pressed' do
    it 'routes with POST' do
      expect(
          post("/#{controller_name}/dialog_form_button_pressed")
      ).to route_to("#{controller_name}#dialog_form_button_pressed")
    end
  end

  describe "#dynamic_list_refresh" do
    it "routes with POST" do
      expect(post("/#{controller_name}/dynamic_list_refresh")).to route_to("#{controller_name}#dynamic_list_refresh")
    end
  end

  describe '#launch_vmware_console' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/launch_vmware_console")).to route_to("#{controller_name}#launch_vmware_console")
    end
  end

  describe '#ontap_file_shares' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ontap_file_shares")).to route_to("#{controller_name}#ontap_file_shares")
    end
  end

  describe '#ontap_logical_disks' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ontap_logical_disks")).to route_to("#{controller_name}#ontap_logical_disks")
    end
  end

  describe '#ontap_storage_systems' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ontap_storage_systems")).to route_to("#{controller_name}#ontap_storage_systems")
    end
  end

  describe '#ontap_storage_volume' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ontap_storage_volume")).to route_to("#{controller_name}#ontap_storage_volume")
    end
  end

  describe '#policies' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/policies")).to route_to("#{controller_name}#policies")
    end
  end

  describe '#pre_prov' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/pre_prov")).to route_to("#{controller_name}#pre_prov")
    end
  end

  describe '#pre_prov_continue' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/pre_prov_continue")).to route_to("#{controller_name}#pre_prov_continue")
    end
  end

  describe '#reconfigure_field_changed' do
    it 'routes with POST' do
      expect(
          post("/#{controller_name}/reconfigure_field_changed")
      ).to route_to("#{controller_name}#reconfigure_field_changed")
    end
  end

  describe '#snap_pressed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/snap_pressed")).to route_to("#{controller_name}#snap_pressed")
    end
  end

  describe '#snap_vm' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/snap_vm")).to route_to("#{controller_name}#snap_vm")
    end
  end

  describe '#reconfigure_update' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/reconfigure_update")).to route_to("#{controller_name}#reconfigure_update")
    end
  end

  describe '#vm_pre_prov' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/vm_pre_prov")).to route_to("#{controller_name}#vm_pre_prov")
    end
  end

  describe '#sort_ds_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_ds_grid")).to route_to("#{controller_name}#sort_ds_grid")
    end
  end

  describe '#sort_host_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_host_grid")).to route_to("#{controller_name}#sort_host_grid")
    end
  end

  describe '#sort_vc_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_vc_grid")).to route_to("#{controller_name}#sort_vc_grid")
    end
  end

  describe '#sort_vm_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_vm_grid")).to route_to("#{controller_name}#sort_vm_grid")
    end
  end

  describe '#sort_iso_img_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_iso_img_grid")).to route_to("#{controller_name}#sort_iso_img_grid")
    end
  end

  describe '#vmrc_console' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/vmrc_console")).to route_to("#{controller_name}#vmrc_console")
    end
  end
end
