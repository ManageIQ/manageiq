require 'spec_helper'
require 'routing/shared_examples'

describe 'routes for CatalogController' do
  let(:controller_name) { 'catalog' }

  it_behaves_like 'A controller that has column width routes'
  it_behaves_like 'A controller that has download_data routes'
  it_behaves_like 'A controller that has explorer routes'

  %w(
    download_data
    explorer
    show
  ).each do |path|
    describe "##{path}" do
      it "routes with GET" do
        expect(get("/#{controller_name}/#{path}")).to route_to("#{controller_name}##{path}")
      end
    end
  end

  %w(
    accordion_select
    ae_tree_select
    ae_tree_select_discard
    ae_tree_select_toggle
    atomic_form_field_changed
    atomic_st_edit
    automate_button_field_changed
    button_create
    button_update
    dialog_field_changed
    dialog_form_button_pressed
    dynamic_list_refresh
    explorer
    get_ae_tree_edit_key
    group_create
    group_form_field_changed
    group_update
    identify_catalog
    process_sts
    prov_field_changed
    reload
    resolve
    resource_delete
    save_col_widths
    servicetemplate_edit
    sort_ds_grid
    sort_host_grid
    sort_iso_img_grid
    sort_pxe_img_grid
    sort_vm_grid
    st_catalog_edit
    st_catalog_form_field_changed
    st_delete
    st_edit
    st_form_field_changed
    st_tags_edit
    st_upload_image
    svc_catalog_provision
    tag_edit_form_field_changed
    tree_autoload_dynatree
    tree_select
    x_button
    x_history
    x_settings_changed
    x_show
  ).each do |path|
    describe "##{path}" do
      it "routes with POST" do
        expect(post("/#{controller_name}/#{path}")).to route_to("#{controller_name}##{path}")
      end
    end
  end
end
