require "spec_helper"
require "routing/shared_examples"

describe "routing for OpsController" do
  let(:controller_name) { "ops" }

  %w(
    explorer
    fetch_audit_log
    fetch_build
    fetch_log
    fetch_production_log
    schedule_form_fields
    show_product_update
  ).each do |task|
    describe "##{task}" do
      it 'routes with GET' do
        expect(get("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end

  %w(
    accordion_select
    activate
    apply_imports
    ap_ce_delete
    ap_ce_select
    ap_edit
    ap_form_field_changed
    ap_set_active_tab
    aps_list
    category_delete
    category_edit
    category_field_changed
    category_update
    ce_accept
    ce_delete
    ce_new_cat
    ce_select
    change_tab
    cu_collection_field_changed
    cu_collection_update
    cu_repair
    cu_repair_field_changed
    db_backup
    db_backup_form_field_changed
    db_gc_collection
    db_list
    diagnostics_server_list
    diagnostics_tree_select
    diagnostics_worker_selected
    edit_rhn
    explorer
    fetch_build
    forest_accept
    forest_delete
    forest_form_field_changed
    forest_select
    log_depot_edit
    log_depot_field_changed
    log_depot_validate
    orphaned_records_delete
    perf_chart_chooser
    product_updates_list
    rbac_group_edit
    rbac_group_field_changed
    rbac_group_seq_edit
    rbac_group_user_lookup
    rbac_groups_list
    rbac_role_edit
    rbac_role_field_changed
    rbac_roles_list
    rbac_tags_edit
    rbac_user_edit
    rbac_user_field_changed
    rbac_users_list
    region_edit
    region_form_field_changed
    repo_default_name
    restart_server
    rhn_buttons
    rhn_default_server
    rhn_validate
    schedule_edit
    schedule_form_field_changed
    schedule_form_filter_type_field_changed
    schedules_list
    schedule_update
    settings_form_field_changed
    settings_update
    show
    show_product_update
    smartproxy_affinity_field_changed
    tag_edit_form_field_changed
    tl_chooser
    tree_autoload_dynatree
    tree_select
    update
    upload_csv
    upload_form_field_changed
    upload_login_logo
    upload_logo
    validate_replcation_worker
    wait_for_task
    x_button
    x_show
    zone_edit
    zone_field_changed
  ).each do |task|
    describe "##{task}" do
      it 'routes with POST' do
        expect(post("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end
end
