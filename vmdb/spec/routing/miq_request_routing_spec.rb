require 'spec_helper'
require 'routing/shared_examples'

describe 'routes for MiqRequestController' do
  let(:controller_name) { 'miq_request' }

  it_behaves_like 'A controller that has show list routes'
  it_behaves_like 'A controller that has column width routes'

  describe '#index' do
    it 'routes with GET' do
      expect(get("/#{controller_name}")).to route_to("#{controller_name}#index")
    end
  end

  describe '#button' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/button")).to route_to("#{controller_name}#button")
    end
  end

  describe '#post_install_callback' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/post_install_callback")).to route_to("#{controller_name}#post_install_callback")
    end
  end

  describe '#pre_prov' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/pre_prov")).to route_to("#{controller_name}#pre_prov")
    end

    it 'routes with POST' do
      expect(post("/#{controller_name}/pre_prov")).to route_to("#{controller_name}#pre_prov")
    end
  end

  describe '#prov_button' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/prov_button")).to route_to("#{controller_name}#prov_button")
    end
  end

  describe '#prov_copy' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/prov_copy")).to route_to("#{controller_name}#prov_copy")
    end
  end

  describe '#prov_change_options' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/prov_change_options")).to route_to("#{controller_name}#prov_change_options")
    end
  end

  describe '#prov_continue' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/prov_continue")).to route_to("#{controller_name}#prov_continue")
    end
  end

  describe '#prov_edit' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/prov_edit")).to route_to("#{controller_name}#prov_edit")
    end

    it 'routes with POST' do
      expect(post("/#{controller_name}/prov_edit")).to route_to("#{controller_name}#prov_edit")
    end
  end

  describe '#prov_load_tab' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/prov_load_tab")).to route_to("#{controller_name}#prov_load_tab")
    end
  end

  describe '#prov_show_option' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/prov_show_option")).to route_to("#{controller_name}#prov_show_option")
    end
  end

  describe '#request_copy' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/request_copy")).to route_to("#{controller_name}#request_copy")
    end
  end

  describe '#request_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/request_edit")).to route_to("#{controller_name}#request_edit")
    end
  end

  describe '#retrieve_email' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/retrieve_email")).to route_to("#{controller_name}#retrieve_email")
    end
  end

  describe '#upload' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/upload")).to route_to("#{controller_name}#upload")
    end
  end

  describe '#show' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/show")).to route_to("#{controller_name}#show")
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

  describe '#sort_iso_img_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_iso_img_grid")).to route_to("#{controller_name}#sort_iso_img_grid")
    end
  end

  describe '#sort_pxe_img_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_pxe_img_grid")).to route_to("#{controller_name}#sort_pxe_img_grid")
    end
  end

  describe '#sort_template_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_template_grid")).to route_to("#{controller_name}#sort_template_grid")
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

  describe '#sort_windows_image_grid' do
    it 'routes with POST' do
      expect(
        post("/#{controller_name}/sort_windows_image_grid")
      ).to route_to("#{controller_name}#sort_windows_image_grid")
    end
  end

  describe '#stamp' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/stamp")).to route_to("#{controller_name}#stamp")
    end

    it 'routes with POST' do
      expect(post("/#{controller_name}/stamp")).to route_to("#{controller_name}#stamp")
    end
  end

  describe '#stamp_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/stamp_field_changed")).to route_to("#{controller_name}#stamp_field_changed")
    end
  end

  describe '#vm_pre_prov' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/vm_pre_prov")).to route_to("#{controller_name}#vm_pre_prov")
    end
  end
end
