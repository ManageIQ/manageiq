require 'spec_helper'
require 'routing/shared_examples'

describe 'routes for CatalogController' do
  let(:controller_name) { 'catalog' }

  it_behaves_like 'A controller that has column width routes'
  it_behaves_like 'A controller that has download_data routes'
  it_behaves_like 'A controller that has explorer routes'

  describe '#ae_tree_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ae_tree_select"))
        .to route_to("#{controller_name}#ae_tree_select")
    end
  end

  describe '#ae_tree_select_discard' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ae_tree_select_discard"))
        .to route_to("#{controller_name}#ae_tree_select_discard")
    end
  end

  describe '#ae_tree_select_toggle' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ae_tree_select_toggle"))
        .to route_to("#{controller_name}#ae_tree_select_toggle")
    end
  end

  describe '#atomic_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/atomic_form_field_changed"))
        .to route_to("#{controller_name}#atomic_form_field_changed")
    end
  end

  describe '#atomic_st_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/atomic_st_edit"))
        .to route_to("#{controller_name}#atomic_st_edit")
    end
  end

  describe '#automate_button_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/automate_button_field_changed"))
        .to route_to("#{controller_name}#automate_button_field_changed")
    end
  end

  describe '#button_create' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/button_create"))
        .to route_to("#{controller_name}#button_create")
    end
  end

  describe '#button_update' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/button_update"))
        .to route_to("#{controller_name}#button_update")
    end
  end

  describe '#dialog_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/dialog_field_changed"))
        .to route_to("#{controller_name}#dialog_field_changed")
    end
  end

  describe '#dialog_form_button_pressed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/dialog_form_button_pressed"))
        .to route_to("#{controller_name}#dialog_form_button_pressed")
    end
  end

  describe '#dynamic_list_refresh' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/dynamic_list_refresh"))
        .to route_to("#{controller_name}#dynamic_list_refresh")
    end
  end

  describe '#explorer' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/explorer")).to route_to("#{controller_name}#explorer")
    end
    # GET method is tested in shared_examples/explorer_examples.rb
  end

  describe '#get_ae_tree_edit_key' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/get_ae_tree_edit_key"))
        .to route_to("#{controller_name}#get_ae_tree_edit_key")
    end
  end

  describe '#group_create' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/group_create"))
        .to route_to("#{controller_name}#group_create")
    end
  end

  describe '#group_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/group_form_field_changed"))
        .to route_to("#{controller_name}#group_form_field_changed")
    end
  end

  describe '#identify_catalog' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/identify_catalog"))
        .to route_to("#{controller_name}#identify_catalog")
    end
  end

  describe '#process_sts' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/process_sts")).to route_to("#{controller_name}#process_sts")
    end
  end

  describe '#prov_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/prov_field_changed"))
        .to route_to("#{controller_name}#prov_field_changed")
    end
  end

  describe '#reload' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/reload")).to route_to("#{controller_name}#reload")
    end
  end

  describe '#resolve' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/resolve")).to route_to("#{controller_name}#resolve")
    end
  end

  describe '#resource_delete' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/resource_delete"))
        .to route_to("#{controller_name}#resource_delete")
    end
  end

  describe '#servicetemplate_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/servicetemplate_edit"))
        .to route_to("#{controller_name}#servicetemplate_edit")
    end
  end

  describe '#show' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/show")).to route_to("#{controller_name}#show")
    end
  end

  describe '#st_catalog_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/st_catalog_edit"))
        .to route_to("#{controller_name}#st_catalog_edit")
    end
  end

  describe '#sort_ds_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_ds_grid"))
        .to route_to("#{controller_name}#sort_ds_grid")
    end
  end

  describe '#sort_host_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_host_grid"))
        .to route_to("#{controller_name}#sort_host_grid")
    end
  end

  describe '#sort_iso_img_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_iso_img_grid"))
        .to route_to("#{controller_name}#sort_iso_img_grid")
    end
  end

  describe '#sort_pxe_img_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_pxe_img_grid"))
      .to route_to("#{controller_name}#sort_pxe_img_grid")
    end
  end

  describe '#sort_vm_grid' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/sort_vm_grid"))
        .to route_to("#{controller_name}#sort_vm_grid")
    end
  end

  describe '#st_catalog_form_field_changed' do
    it 'routes with POST' do
      expect(
        post("/#{controller_name}/st_catalog_form_field_changed")
      ).to route_to("#{controller_name}#st_catalog_form_field_changed")
    end
  end

  describe '#st_delete' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/st_delete")).to route_to("#{controller_name}#st_delete")
    end
  end

  describe '#st_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/st_edit")).to route_to("#{controller_name}#st_edit")
    end
  end

  describe '#st_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/st_form_field_changed"))
      .to route_to("#{controller_name}#st_form_field_changed")
    end
  end

  describe '#st_tags_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/st_tags_edit"))
        .to route_to("#{controller_name}#st_tags_edit")
    end
  end

  describe '#st_upload_image' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/st_upload_image"))
        .to route_to("#{controller_name}#st_upload_image")
    end
  end

  describe '#svc_catalog_provision' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/svc_catalog_provision"))
        .to route_to("#{controller_name}#svc_catalog_provision")
    end
  end

  describe '#x_show' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_show")).to route_to("#{controller_name}#x_show")
    end
  end

  describe '#x_button' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_button")).to route_to("#{controller_name}#x_button")
    end
  end

  describe '#x_history' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_history")).to route_to("#{controller_name}#x_history")
    end
  end
end
