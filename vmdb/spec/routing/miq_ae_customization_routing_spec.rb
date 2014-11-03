require "spec_helper"
require "routing/shared_examples"

describe MiqAeCustomizationController do
  let(:controller_name) { 'miq_ae_customization' }

  it_behaves_like "A controller that has column width routes"

  %w(
    explorer
    export_service_dialogs
    review_import
    service_dialog_json
  ).each do |path|
    describe "##{path}" do
      it "routes with GET" do
        expect(get("/#{controller_name}/#{path}")).to route_to("#{controller_name}##{path}")
      end
    end
  end

  %w(
    ab_group_reorder
    ae_tree_select
    ae_tree_select_toggle
    accordion_select
    automate_button_field_changed
    button_create
    button_update
    cancel_import
    change_tab
    dialog_edit
    dialog_form_field_changed
    dialog_list
    dialog_res_remove
    dialog_res_reorder
    explorer
    field_value_accept
    field_value_delete
    field_value_select
    group_create
    group_form_field_changed
    group_reorder_field_changed
    group_update
    import_service_dialogs
    old_dialogs_form_field_changed
    old_dialogs_list
    old_dialogs_update
    reload
    resolve
    save_col_widths
    tree_autoload_dynatree
    tree_select
    upload_import_file
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
