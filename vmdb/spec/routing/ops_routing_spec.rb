require "spec_helper"
require "routing/shared_examples"

describe "routing for OpsController" do
  let(:controller_name) { "ops" }

  describe '#explorer' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/explorer")).to route_to("#{controller_name}#explorer")
    end
  end

  describe '#fetch_audit_log' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/fetch_audit_log")).to route_to("#{controller_name}#fetch_audit_log")
    end
  end

  describe '#fetch_build' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/fetch_build")).to route_to("#{controller_name}#fetch_build")
    end
  end

  describe '#fetch_log' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/fetch_log")).to route_to("#{controller_name}#fetch_log")
    end
  end

  describe '#fetch_production_log' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/fetch_production_log")).to route_to("#{controller_name}#fetch_production_log")
    end
  end

  describe '#show_product_update' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/show_product_update")).to route_to("#{controller_name}#show_product_update")
    end
  end

  describe '#accordion_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/accordion_select")).to route_to("#{controller_name}#accordion_select")
    end
  end

  describe '#activate' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/activate")).to route_to("#{controller_name}#activate")
    end
  end

  describe '#apply_imports' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/apply_imports")).to route_to("#{controller_name}#apply_imports")
    end
  end

  describe '#ap_ce_delete' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ap_ce_delete")).to route_to("#{controller_name}#ap_ce_delete")
    end
  end

  describe '#ap_ce_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ap_ce_select")).to route_to("#{controller_name}#ap_ce_select")
    end
  end

  describe '#ap_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ap_edit")).to route_to("#{controller_name}#ap_edit")
    end
  end

  describe '#ap_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ap_form_field_changed")).to route_to("#{controller_name}#ap_form_field_changed")
    end
  end

  describe '#ap_set_active_tab' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ap_set_active_tab")).to route_to("#{controller_name}#ap_set_active_tab")
    end
  end

  describe '#aps_list' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/aps_list")).to route_to("#{controller_name}#aps_list")
    end
  end

  describe '#category_delete' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/category_delete")).to route_to("#{controller_name}#category_delete")
    end
  end

  describe '#category_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/category_edit")).to route_to("#{controller_name}#category_edit")
    end
  end

  describe '#category_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/category_field_changed")).to route_to("#{controller_name}#category_field_changed")
    end
  end

  describe '#category_update' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/category_update")).to route_to("#{controller_name}#category_update")
    end
  end

  describe '#ce_accept' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ce_accept")).to route_to("#{controller_name}#ce_accept")
    end
  end

  describe '#ce_delete' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ce_delete")).to route_to("#{controller_name}#ce_delete")
    end
  end

  describe '#ce_new_cat' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ce_new_cat")).to route_to("#{controller_name}#ce_new_cat")
    end
  end

  describe '#ce_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/ce_select")).to route_to("#{controller_name}#ce_select")
    end
  end

  describe '#change_tab' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/change_tab")).to route_to("#{controller_name}#change_tab")
    end
  end

  describe '#cu_collection_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/cu_collection_field_changed")).to route_to("#{controller_name}#cu_collection_field_changed")
    end
  end

  describe '#cu_collection_update' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/cu_collection_update")).to route_to("#{controller_name}#cu_collection_update")
    end
  end

  describe '#cu_repair' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/cu_repair")).to route_to("#{controller_name}#cu_repair")
    end
  end

  describe '#cu_repair_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/cu_repair_field_changed")).to route_to("#{controller_name}#cu_repair_field_changed")
    end
  end

  describe '#db_backup' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/db_backup")).to route_to("#{controller_name}#db_backup")
    end
  end

  describe '#db_backup_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/db_backup_form_field_changed")).to route_to("#{controller_name}#db_backup_form_field_changed")
    end
  end

  describe '#db_gc_collection' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/db_gc_collection")).to route_to("#{controller_name}#db_gc_collection")
    end
  end

  describe '#diagnostics_server_list' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/diagnostics_server_list")).to route_to("#{controller_name}#diagnostics_server_list")
    end
  end

  describe '#diagnostics_tree_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/diagnostics_tree_select")).to route_to("#{controller_name}#diagnostics_tree_select")
    end
  end

  describe '#diagnostics_worker_selected' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/diagnostics_worker_selected")).to route_to("#{controller_name}#diagnostics_worker_selected")
    end
  end

  describe '#edit_rhn' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/edit_rhn")).to route_to("#{controller_name}#edit_rhn")
    end
  end

  describe '#explorer' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/explorer")).to route_to("#{controller_name}#explorer")
    end
  end

  describe '#fetch_build' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/fetch_build")).to route_to("#{controller_name}#fetch_build")
    end
  end

  describe '#forest_accept' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/forest_accept")).to route_to("#{controller_name}#forest_accept")
    end
  end

  describe '#forest_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/forest_form_field_changed")).to route_to("#{controller_name}#forest_form_field_changed")
    end
  end

  describe '#forest_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/forest_select")).to route_to("#{controller_name}#forest_select")
    end
  end

  describe '#log_depot_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/log_depot_edit")).to route_to("#{controller_name}#log_depot_edit")
    end
  end

  describe '#log_depot_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/log_depot_field_changed")).to route_to("#{controller_name}#log_depot_field_changed")
    end
  end

  describe '#orphaned_records_delete' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/orphaned_records_delete")).to route_to("#{controller_name}#orphaned_records_delete")
    end
  end

  describe '#perf_chart_chooser' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/perf_chart_chooser")).to route_to("#{controller_name}#perf_chart_chooser")
    end
  end

  describe '#product_updates_list' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/product_updates_list")).to route_to("#{controller_name}#product_updates_list")
    end
  end

  describe '#rbac_group_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_group_edit")).to route_to("#{controller_name}#rbac_group_edit")
    end
  end

  describe '#rbac_group_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_group_field_changed")).to route_to("#{controller_name}#rbac_group_field_changed")
    end
  end

  describe '#rbac_group_seq_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_group_seq_edit")).to route_to("#{controller_name}#rbac_group_seq_edit")
    end
  end

  describe '#rbac_group_user_lookup' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_group_user_lookup")).to route_to("#{controller_name}#rbac_group_user_lookup")
    end
  end

  describe '#rbac_groups_list' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_groups_list")).to route_to("#{controller_name}#rbac_groups_list")
    end
  end

  describe '#rbac_role_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_role_edit")).to route_to("#{controller_name}#rbac_role_edit")
    end
  end

  describe '#rbac_role_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_role_field_changed")).to route_to("#{controller_name}#rbac_role_field_changed")
    end
  end

  describe '#rbac_roles_list' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_roles_list")).to route_to("#{controller_name}#rbac_roles_list")
    end
  end

  describe '#rbac_tags_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_tags_edit")).to route_to("#{controller_name}#rbac_tags_edit")
    end
  end

  describe '#rbac_user_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_user_edit")).to route_to("#{controller_name}#rbac_user_edit")
    end
  end

  describe '#rbac_user_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_user_field_changed")).to route_to("#{controller_name}#rbac_user_field_changed")
    end
  end

  describe '#rbac_users_list' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rbac_users_list")).to route_to("#{controller_name}#rbac_users_list")
    end
  end

  describe '#region_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/region_edit")).to route_to("#{controller_name}#region_edit")
    end
  end

  describe '#region_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/region_form_field_changed")).to route_to("#{controller_name}#region_form_field_changed")
    end
  end

  describe '#repo_default_name' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/repo_default_name")).to route_to("#{controller_name}#repo_default_name")
    end
  end

  describe '#restart_server' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/restart_server")).to route_to("#{controller_name}#restart_server")
    end
  end

  describe '#rhn_buttons' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rhn_buttons")).to route_to("#{controller_name}#rhn_buttons")
    end
  end

  describe '#rhn_default_server' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rhn_default_server")).to route_to("#{controller_name}#rhn_default_server")
    end
  end

  describe '#rhn_validate' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/rhn_validate")).to route_to("#{controller_name}#rhn_validate")
    end
  end

  describe '#schedule_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/schedule_edit")).to route_to("#{controller_name}#schedule_edit")
    end
  end

  describe '#schedule_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/schedule_form_field_changed")).to route_to("#{controller_name}#schedule_form_field_changed")
    end
  end

  describe '#schedules_list' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/schedules_list")).to route_to("#{controller_name}#schedules_list")
    end
  end

  describe '#schedule_update' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/schedule_update")).to route_to("#{controller_name}#schedule_update")
    end
  end

  describe '#settings_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/settings_form_field_changed")).to route_to("#{controller_name}#settings_form_field_changed")
    end
  end

  describe '#settings_update' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/settings_update")).to route_to("#{controller_name}#settings_update")
    end
  end

  describe '#show' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/show")).to route_to("#{controller_name}#show")
    end
  end

  describe '#show_product_update' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/show_product_update")).to route_to("#{controller_name}#show_product_update")
    end
  end

  describe '#smartproxy_affinity_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/smartproxy_affinity_field_changed")).to route_to("#{controller_name}#smartproxy_affinity_field_changed")
    end
  end

  describe '#tag_edit_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/tag_edit_form_field_changed")).to route_to("#{controller_name}#tag_edit_form_field_changed")
    end
  end

  describe '#tl_chooser' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/tl_chooser")).to route_to("#{controller_name}#tl_chooser")
    end
  end

  describe '#tree_autoload_dynatree' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/tree_autoload_dynatree")).to route_to("#{controller_name}#tree_autoload_dynatree")
    end
  end

  describe '#tree_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/tree_select")).to route_to("#{controller_name}#tree_select")
    end
  end

  describe '#upload_csv' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/upload_csv")).to route_to("#{controller_name}#upload_csv")
    end
  end

  describe '#upload_form_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/upload_form_field_changed")).to route_to("#{controller_name}#upload_form_field_changed")
    end
  end

  describe '#upload_login_logo' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/upload_login_logo")).to route_to("#{controller_name}#upload_login_logo")
    end
  end

  describe '#upload_logo' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/upload_logo")).to route_to("#{controller_name}#upload_logo")
    end
  end

  describe '#upload_updates' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/upload_updates")).to route_to("#{controller_name}#upload_updates")
    end
  end

  describe '#validate_replcation_worker' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/validate_replcation_worker")).to route_to("#{controller_name}#validate_replcation_worker")
    end
  end

  describe '#wait_for_task' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/wait_for_task")).to route_to("#{controller_name}#wait_for_task")
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

  describe '#zone_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/zone_edit")).to route_to("#{controller_name}#zone_edit")
    end
  end

  describe '#zone_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/zone_field_changed")).to route_to("#{controller_name}#zone_field_changed")
    end
  end
end
