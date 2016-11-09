module Sandbox
  #
  # Explorer shortcuts to the current tree and tree node
  #

  def sandbox
    @sb ||= {}
  end

  # Return the current tree history array
  def x_tree_history
    sandbox[:history] ||= {}
    sandbox[:history][x_active_tree] ||= []
    sandbox[:history][x_active_tree]
  end

  def x_tree_init(name, type, leaf)
    return if sandbox.has_key_path?(:trees, name)

    values = {
      :tree       => name,
      :type       => type,
      :leaf       => leaf,
      :add_root   => true,
      :open_nodes => []
    }

    sandbox.store_path(:trees, name, values)
  end

  def x_active_tree
    sandbox[:active_tree]
  end

  TREE_WHITELIST = %w(
    ab_tree
    action_tree
    ae_tree
    alert_profile_tree
    alert_tree
    automate_tree
    bottlenecks_tree
    cb_assignments_tree
    cb_rates_tree
    cb_reports_tree
    cluster_tree
    configuration_scripts_tree
    condition_tree
    containers_tree
    containers_filter_tree
    cs_filter_tree
    customization_templates_tree
    datacenter_tree
    datastore_tree
    db_tree
    df_tree
    diagnostics_tree
    dialog_edit_tree
    dialog_import_export_tree
    dialogs_tree
    event_tree
    export_tree
    images_filter_tree
    images_tree
    infra_networking_tree
    instances_filter_tree
    instances_tree
    iso_datastores_tree
    network_tree
    old_dialogs_tree
    ot_tree
    network_tree
    policy_profile_tree
    policy_tree
    policy_simulation_tree
    protect_tree
    pxe_image_types_tree
    pxe_servers_tree
    configuration_manager_providers_tree
    rbac_tree
    reports_tree
    roles_by_server_tree
    roles_tree
    rsop_tree
    sa_tree
    sandt_tree
    savedreports_tree
    schedules_tree
    servers_by_role_tree
    settings_tree
    snapshot_tree
    stcat_tree
    storage_tree
    storage_pod_tree
    svccat_tree
    svcs_tree
    templates_filter_tree
    templates_images_filter_tree
    utilization_tree
    vandt_tree
    vat_tree
    vmdb_tree
    vms_filter_tree
    vms_instances_filter_tree
    widgets_tree
  ).each_with_object({}) { |value, acc| acc[value] = value.to_sym }.freeze

  ACCORD_WHITELIST = %w(
    ab
    action
    alert
    alert_profile
    cb_assignments
    cb_rates
    cb_reports
    configuration_scripts
    condition
    containers
    containers_filter
    cs_filter
    customization_templates
    datastores
    db
    diagnostics
    dialog_import_export
    dialogs
    event
    export
    configuration_manager_providers
    images
    images_filter
    instances
    instances_filter
    infra_networking
    iso_datastores
    old_dialogs
    ot
    policy
    policy_profile
    pxe_image_types
    pxe_servers
    rbac
    reports
    roles
    sandt
    savedreports
    schedules
    settings
    stcat
    storage
    storage_pod
    svccat
    svcs
    templates_filter
    templates_images_filter
    templates_images_filter
    vandt
    vmdb
    vms_filter
    vms_instances_filter
    widgets
  ).each_with_object({}) { |value, acc| acc[value] = value.to_sym }.freeze

  def x_active_tree=(tree)
    sandbox[:active_tree] = nil
    return if tree.nil?

    raise ActionController::RoutingError, 'invalid tree' unless TREE_WHITELIST.key?(tree.to_s)
    sandbox[:active_tree] = TREE_WHITELIST[tree.to_s]
  end

  def x_active_accord=(tree)
    sandbox[:active_accord] = nil

    raise ActionController::RoutingError, 'invalid accordion' unless ACCORD_WHITELIST.key?(tree)
    sandbox[:active_accord] = ACCORD_WHITELIST[tree]
  end

  def x_active_accord
    sandbox[:active_accord]
  end

  def x_tree(tree = nil)
    tree ||= x_active_tree
    sandbox.fetch_path(:trees, tree)
  end

  def x_node(tree = nil)
    tree ||= x_active_tree
    sandbox.fetch_path(:trees, tree, :active_node)
  end

  def x_node=(node)
    x_node_set(node, x_active_tree)
  end

  def x_node_set(node, tree)
    sandbox.store_path(:trees, tree, :active_node, node)
  end

  def edit_typ
    sandbox[:edit_typ]
  end
end
