class ApplicationHelper::ToolbarChooser
  include RestfulControllerMixin

  # Return a blank tb if a placeholder is needed for AJAX explorer screens, return nil if no center toolbar to be shown
  def center_toolbar_filename
    if @explorer
      center_toolbar_filename_explorer
    else
      center_toolbar_filename_classic
    end
  end

  def history_toolbar_filename
    if x_active_tree == :dialogs_tree || %w(chargeback miq_ae_tools miq_capacity_planning miq_capacity_utilization miq_policy_rsop ops).include?(@layout)
      'blank_view_tb'
    else
      'x_history_tb'
    end
  end

  def x_view_toolbar_filename
    if x_gtl_view_tb_render?
      'x_gtl_view_tb'
    elsif %w(miq_capacity_planning miq_capacity_utilization).include?(@layout)
      'miq_capacity_view_tb'
    elsif @record && @explorer && (%w(services catalogs).include?(@layout) || %w(performance timeline).include?(@display))
      'blank_view_tb'
    elsif %w(report).include?(@layout)
      @report ? "report_view_tb" : "blank_view_tb"
    elsif %w(provider_foreman).include?(@layout)
      @showtype == 'main' ? "x_summary_view_tb" : "x_gtl_view_tb"
    else
      'blank_view_tb'
    end
  end

  def view_toolbar_filename
    if render_gtl_view_tb?
      'gtl_view_tb'
    elsif @lastaction == "compare_miq" || @lastaction == "compare_compress"
      'compare_view_tb'
    elsif @lastaction == "drift"
      'drift_view_tb'
    elsif %w(ems_container).include?(@layout) && %w(main dashboard topology).include?(@display)
      'dashboard_summary_toggle_view_tb'
    elsif !%w(all_tasks all_ui_tasks timeline diagnostics my_tasks my_ui_tasks miq_server usage).include?(@layout) &&
          (!@layout.starts_with?("miq_request")) && !@treesize_buttons &&
          @display == "main" && @showtype == "main" && !@in_a_form
      controller_restful? ? "summary_view_restful_tb" : "summary_view_tb"
    else
      'blank_view_tb'
    end
  end

  private

  delegate :session, :from_cid, :x_node, :x_active_tree, :super_admin_user?, :render_gtl_view_tb?, :x_gtl_view_tb_render?,
           :to => :@view_context

  def initialize(view_context, view_binding, instance_data)
    @view_context = view_context
    @view_binding = view_binding

    instance_data.each do |name, value|
      instance_variable_set(:"@#{name}", value)
    end
  end

  ###

  # Return explorer based toolbar file name
  def center_toolbar_filename_explorer
    if @record && @button_group &&
       !["catalogs", "chargeback", "miq_capacity_utilization", "miq_capacity_planning", "services"].include?(@layout)
      if @record.kind_of?(ManageIQ::Providers::Openstack::CloudManager::Vm)
        return "openstack_vm_cloud_center_tb"
      elsif @record.kind_of?(ManageIQ::Providers::CloudManager::Vm)
        return "x_vm_cloud_center_tb"
      elsif @record.kind_of?(ManageIQ::Providers::CloudManager::Template)
        return "x_template_cloud_center_tb"
      elsif @button_group.eql? "snapshot"
        return "x_vm_center_tb"
      else
        return "x_#{@button_group}_center_tb"
      end
    else
      if ["vm_cloud", "vm_infra", "vm_or_template"].include?(@layout)
        if @record
          if @display == "performance"
            return "vm_performance_tb"
          end
        else
          return  case x_active_tree
                  when :images_filter_tree, :images_tree then         "template_clouds_center_tb"
                  when :instances_filter_tree, :instances_tree then  "vm_clouds_center_tb"
                  when :templates_images_filter_tree then            "miq_templates_center_tb"
                  when :templates_filter_tree then                   "template_infras_center_tb"
                  when :vms_filter_tree, :vandt_tree then            "vm_infras_center_tb"
                  when :vms_instances_filter_tree then               "vms_center_tb"
                  end
        end
      elsif @layout == "provider_foreman" && [:configuration_manager_providers_tree, :cs_filter_tree, :configuration_scripts_tree].include?(x_active_tree)
        return center_toolbar_filename_configuration_manager_providers
      else
        if x_active_tree == :ae_tree
          return center_toolbar_filename_automate
        elsif x_active_tree == :containers_tree
          return center_toolbar_filename_containers
        elsif [:sandt_tree, :svccat_tree, :stcat_tree, :svcs_tree, :ot_tree].include?(x_active_tree)
          return center_toolbar_filename_services
        elsif @layout == "chargeback"
          return center_toolbar_filename_chargeback
        elsif @layout == "miq_ae_tools"
          return super_admin_user? ? "miq_ae_tools_simulate_center_tb" : "blank_view_tb"
        elsif @layout == "miq_policy"
          return center_toolbar_filename_miq_policy
        elsif @layout == "ops"
          return center_toolbar_filename_ops
        elsif @layout == "pxe"
          return center_toolbar_filename_pxe
        elsif @layout == "storage"
          return center_toolbar_filename_storage
        elsif @layout == "report"
          return center_toolbar_filename_report
        elsif @layout == "miq_ae_customization"
          return center_toolbar_filename_automate_customization
        end
      end
    end
    "blank_view_tb"
  end

  def center_toolbar_filename_automate
    nodes = x_node.split('-')
    case nodes.first
    when "root" then "miq_ae_domains_center_tb"
    when "aen"  then domain_or_namespace_toolbar(nodes.last)
    when "aec"  then case @sb[:active_tab]
                     when "methods" then  "miq_ae_methods_center_tb"
                     when "props"   then  "miq_ae_class_center_tb"
                     when "schema"  then  "miq_ae_fields_center_tb"
                     else                 "miq_ae_instances_center_tb"
                     end
    when "aei"  then "miq_ae_instance_center_tb"
    when "aem"  then "miq_ae_method_center_tb"
    end
  end

  def domain_or_namespace_toolbar(node_id)
    ns = MiqAeNamespace.find(from_cid(node_id))
    if ns.domain?
      "miq_ae_domain_center_tb"
    elsif !ns.domain?
      "miq_ae_namespace_center_tb"
    else
      "blank_view_tb"
    end
  end

  def center_toolbar_filename_automate_customization
    if x_active_tree == :old_dialogs_tree
      return @dialog ? "miq_dialog_center_tb" : "miq_dialogs_center_tb"
    elsif x_active_tree == :dialogs_tree
      if x_node == "root"
        return "dialogs_center_tb"
      elsif @record && !@in_a_form
        return "dialog_center_tb"
      end
    elsif x_active_tree == :ab_tree
      if x_node != "root"
        nodes = x_node.split('_')
        if nodes.length == 2 && nodes[0] == "xx-ab"
          return "custom_button_set_center_tb"  # CI node is selected
        elsif (nodes.length == 1 && nodes[0].split('-').length == 3 && nodes[0].split('-')[1] == "ub") ||
              (nodes.length == 3 && nodes[0] == "xx-ab")
          return "custom_buttons_center_tb"     # group node is selected
        else
          return "custom_button_center_tb"      # button node is selected
        end
      end
    elsif @in_a_form      # to show buttons on dialog add/edit screens
      return "dialog_center_tb"
    end
    "blank_view_tb"
  end

  def center_toolbar_filename_services
    if x_active_tree == :sandt_tree
      if TreeBuilder.get_model_for_prefix(@nodetype) == "ServiceTemplate"
        return "servicetemplate_center_tb"
      elsif @sb[:buttons_node]
        nodes = x_node.split('_')
        if nodes.length == 3 && nodes[2].split('-').first == "xx"
          return "catalogitem_button_set_center_tb"
        elsif nodes.length == 4 && nodes[3].split('-').first == "cbg"
          return "catalogitem_buttons_center_tb"
        else
          return "catalogitem_button_center_tb"
        end
      else
        return "servicetemplates_center_tb"
      end
    elsif x_active_tree == :stcat_tree
      if TreeBuilder.get_model_for_prefix(@nodetype) == "ServiceTemplateCatalog"
        return "servicetemplatecatalog_center_tb"
      else
        return "servicetemplatecatalogs_center_tb"
      end
    elsif x_active_tree == :svcs_tree
      if TreeBuilder.get_model_for_prefix(@nodetype) == "Service"
        return "service_center_tb"
      else
        return "services_center_tb"
      end
    elsif x_active_tree == :ot_tree
      if %w(root xx-otcfn xx-othot xx-otazu xx-otvnf).include?(x_node)
        return "orchestration_templates_center_tb"
      else
        return "orchestration_template_center_tb"
      end
    end
  end

  def center_toolbar_filename_containers
    # TreeBuilder.get_model_for_prefix(@nodetype) == "Container" ? "containers_center_tb" : "container_center_tb"
    if x_node == "root"
      return "containers_center_tb"
    else
      return "container_center_tb"
    end
  end

  def center_toolbar_filename_chargeback
    if @report && x_active_tree == :cb_reports_tree
      return "chargeback_center_tb"
    elsif x_active_tree == :cb_rates_tree && x_node != "root"
      if ["Compute", "Storage"].include?(x_node.split('-').last)
        return "chargebacks_center_tb"
      else
        return "chargeback_center_tb"
      end
    end
    "blank_view_tb"
  end

  def center_toolbar_filename_miq_policy
    if @nodetype == "xx"
      if @policies || (@view && @sb[:tree_typ] == "policies")
        return "miq_policies_center_tb"
      elsif @conditions
        return "conditions_center_tb"
      elsif @alert_profiles
        return "miq_alert_profiles_center_tb"
      end
    end
    case @nodetype
    when "root"
      case x_active_tree
      when :policy_profile_tree then  "miq_policy_profiles_center_tb"
      when :action_tree then          "miq_actions_center_tb"
      when :alert_tree then           "miq_alerts_center_tb"
      else                        "blank_view_tb"
      end
    when "pp" then  "miq_policy_profile_center_tb"
    when "p" then   "miq_policy_center_tb"
    when "co" then  "condition_center_tb"
    when "ev" then  "miq_event_center_tb"
    when "a" then   "miq_action_center_tb"
    when "al" then  "miq_alert_center_tb"
    when "ap" then  "miq_alert_profile_center_tb"
    else        "blank_view_tb"
    end
  end

  def center_toolbar_filename_ops
    if x_active_tree == :settings_tree
      if x_node.split('-').last == "msc"
        return "miq_schedules_center_tb"
      elsif x_node.split('-').first == "msc"
        return "miq_schedule_center_tb"
      elsif x_node.split('-').last == "l"
        return "ldap_regions_center_tb"
      elsif x_node.split('-').first == "lr"
        return "ldap_region_center_tb"
      elsif x_node.split('-').first == "ld"
        return "ldap_domain_center_tb"
      elsif x_node.split('-').last == "sis"
        return "scan_profiles_center_tb"
      elsif x_node.split('-').first == "sis"
        return "scan_profile_center_tb"
      elsif x_node.split('-').last == "z"
        return "zones_center_tb"
      elsif x_node.split('-').first == "z" && @sb[:active_tab] != "settings_smartproxy_affinity"
        return "zone_center_tb"
      end
    elsif x_active_tree == :diagnostics_tree
      if x_node == "root"
        return "diagnostics_region_center_tb"
      elsif x_node.split('-').first == "svr"
        return "diagnostics_server_center_tb"
      elsif x_node.split('-').first == "z"
        return "diagnostics_zone_center_tb"
      end
    elsif x_active_tree == :rbac_tree
      node = x_node.split('-')
      if node.last == "g"
        return "miq_groups_center_tb"
      elsif node.first == "g"
        return "miq_group_center_tb"
      elsif node.last == "u"
        return "users_center_tb"
      elsif node.first == "u"
        return "user_center_tb"
      elsif node.last == "ur"
        return "user_roles_center_tb"
      elsif node.first == "ur"
        return "user_role_center_tb"
      elsif node.last == "tn"
        return "tenants_center_tb"
      elsif node.first == "tn" && @record
        return "tenant_center_tb"
      end
    elsif x_active_tree == :vmdb_tree
      if x_node
        return "vmdb_tables_center_tb"
      else
        return "vmdb_table_center_tb"
      end
    end
    "blank_view_tb"
  end

  def center_toolbar_filename_report
    if x_active_tree == :db_tree
      node = x_node
      if node == "root" || node == "xx-g"
        return "blank_view_tb"
      elsif node.split('-').length == 3
        return "miq_widget_sets_center_tb"
      else
        return "miq_widget_set_center_tb"
      end
    elsif x_active_tree == :savedreports_tree
      if x_node == "root" || x_node.split('_').last.split('-').first != "rr"
        return "saved_reports_center_tb"
      else
        return "saved_report_center_tb"
      end
    elsif x_active_tree == :reports_tree
      nodes = x_node.split('-')
      if nodes.length == 5
        # on report show
        return "miq_report_center_tb"
      elsif nodes.length == 6
        # on savedreport in reports tree
        return "saved_report_center_tb"
      else
        # on folder node
        return "miq_reports_center_tb"
      end
    elsif x_active_tree == :schedules_tree
      return x_node == "root" ?
          "miq_report_schedules_center_tb" : "miq_report_schedule_center_tb"
    elsif x_active_tree == :widgets_tree
      node = x_node
      return node == "root" || node.split('-').length == 2 ?
          "miq_widgets_center_tb" : "miq_widget_center_tb"
    end
    "blank_view_tb"
  end

  def center_toolbar_filename_pxe
    if x_active_tree == :pxe_servers_tree
      if x_node == "root"
        return "pxe_servers_center_tb"
      else
        if x_node.split('-').first == "pi"
          return "pxe_image_center_tb"
        elsif x_node.split('-').first == "wi"
          return "windows_image_center_tb"
        else
          return "pxe_server_center_tb"
        end
      end
    elsif x_active_tree == :customization_templates_tree
      if x_node == "root" ||
         x_node.split('-').length == 3
        # root node or folder node selected
        return "customization_templates_center_tb"
      else
        return "customization_template_center_tb"
      end
    elsif x_active_tree == :pxe_image_types_tree
      if x_node == "root"
        return "pxe_image_types_center_tb"
      else
        return "pxe_image_type_center_tb"
      end
    elsif x_active_tree == :iso_datastores_tree
      if x_node == "root"
        return "iso_datastores_center_tb"
      else
        if x_node.split('-').first == "isi"
          # on image node
          return "iso_image_center_tb"
        else
          return "iso_datastore_center_tb"
        end
      end
    end
    "blank_view_tb"
  end

  def center_toolbar_filename_storage
    if x_active_tree == :storage_tree
      if x_node.split('-').first == 'ds'
        return "storage_center_tb"
      else
        return "storages_center_tb"
      end
    elsif x_active_tree == :storage_pod_tree
      nodetype =  x_node.split('-').first
      if nodetype == 'ds'
        return "storage_center_tb"
      elsif nodetype != 'root'
        return "storages_center_tb"
      end
    end
    "blank_view_tb"
  end

  # Return non-explorer based toolbar file name
  def center_toolbar_filename_classic
    return "#{@center_toolbar}_center_tb" if @center_toolbar

    # Original non vmx view code follows
    # toolbar buttons on sub-screens
    to_display = %w(availability_zones cloud_networks cloud_object_store_containers cloud_subnets
                    cloud_tenants cloud_volumes ems_clusters flavors floating_ips hosts load_balancers
                    network_ports network_routers orchestration_stacks resource_pools security_groups storages)
    to_display_center = %w(stack_orchestration_template topology)
    if @lastaction == 'show' && (@view || @display != 'main') && !@layout.starts_with?("miq_request")
      if @display == "vms" || @display == "all_vms"
        return "vm_infras_center_tb"
      elsif @display == "images"
        return "template_clouds_center_tb"
      elsif @display == "instances"
        return "vm_clouds_center_tb"
      elsif @display == "miq_templates"
        return "template_infras_center_tb"
      elsif (@layout == "vm" || @layout == "host") && @display == "performance"
        return "#{@explorer ? "x_" : ""}vm_performance_tb"
      elsif @display == "dashboard"
        return "#{@layout}_center_tb"
      elsif to_display.include?(@display)
        return "#{@display}_center_tb"
      elsif to_display_center.include?(@display)
        return "#{@display}_center"
      end
    elsif @lastaction == "arbitration_profiles"
      return @showtype == "item" ? "arbitration_profile_center_tb" : "arbitration_profiles_center_tb"
    elsif @lastaction == "compare_miq" || @lastaction == "compare_compress"
      return "compare_center_tb"
    elsif @lastaction == "drift_history"
      return "drifts_center_tb"
    elsif @lastaction == "drift"
      return "drift_center_tb"
    else
      # show_list and show screens
      unless @in_a_form
        if %w(auth_key_pair_cloud availability_zone cloud_object_store_object cloud_object_store_container cloud_tenant
              cloud_volume cloud_volume_backup cloud_volume_snapshot configuration_job container_group container_node container_service
              ems_cloud ems_cluster ems_container ems_middleware container_project container_route container_replicator container_image
              ems_network security_group floating_ip cloud_subnet network_router network_topology network_port cloud_network load_balancer
              container_image_registry ems_infra flavor host container_build infra_networking
              ontap_file_share ontap_logical_disk container_topology middleware_topology middleware_server
              middleware_deployment middleware_datasource middleware_domain middleware_server_group middleware_messaging
              ontap_storage_system orchestration_stack resource_pool storage_manager
              timeline usage).include?(@layout)
          if ["show_list"].include?(@lastaction)
            return "#{@layout.pluralize}_center_tb"
          else
            return "#{@layout}_center_tb"
          end
        elsif @layout == "configuration" && @tabform == "ui_4"
          return "time_profiles_center_tb"
        elsif @layout == "diagnostics"
          return "diagnostics_center_tb"
        elsif @layout == "miq_policy_logs" || @layout == "miq_ae_logs"
          return "logs_center_tb"
        elsif @layout.starts_with?("miq_request_")
          if ["show_list"].include?(@lastaction)
            return "miq_requests_center_tb"
          else
            return "miq_request_center_tb"
          end
        elsif ["my_tasks", "my_ui_tasks", "all_tasks", "all_ui_tasks"].include?(@layout)
          return "tasks_center_tb"
        end
      end
    end
    "blank_view_tb"
  end

  def center_toolbar_filename_configuration_manager_providers
    nodes = x_node.split('-')
    if x_active_tree == :configuration_manager_providers_tree
      configuration_manager_providers_tree_center_tb(nodes)
    elsif x_active_tree == :cs_filter_tree
      cs_filter_tree_center_tb(nodes)
    elsif x_active_tree == :configuration_scripts_tree
      configuration_scripts_tree_center_tb(nodes)
    end
  end

  def configuration_manager_providers_tree_center_tb(nodes)
    case nodes.first
    when "root"     then  "provider_foreman_center_tb"
    when "fr", "at" then  "configuration_profile_foreman_center_tb"
    when "cp"       then  configuration_profile_center_tb
    when "f"        then  inventory_group_center_tb
    when "xx"       then
      case nodes.last
      when "f"  then "configured_systems_ansible_center_tb"
      when "cp" then "configured_systems_foreman_center_tb"
      else "provider_foreman_center_tb"
      end
    else unassigned_configuration_profile_node(nodes)
    end
  end

  def cs_filter_tree_center_tb(nodes)
    case nodes.first
    when "root", "ms", "xx", "csa", "csf" then "configured_system_foreman_center_tb"
    end
  end

  def configuration_scripts_tree_center_tb(nodes)
    if %w(root at).include?(nodes.first)
      "configuration_scripts_center_tb"
    else
      "configuration_script_center_tb"
    end
  end

  def configuration_profile_center_tb
    if @sb[:active_tab] == "configured_systems"
      "configured_systems_foreman_center_tb"
    else
      "blank_view_tb"
    end
  end

  def inventory_group_center_tb
    if @sb[:active_tab] == "configured_systems"
      "configured_systems_ansible_center_tb"
    else
      "blank_view_tb"
    end
  end

  def unassigned_configuration_profile_node(nodes)
    configuration_profile_center_tb if nodes[2] == "unassigned"
  end
end
