module Sandbox
  #
  # Explorer shortcuts to the current tree and tree node
  #

  # Return the current tree history array
  def x_tree_history
    @sb[:history] ||= {}
    @sb[:history][x_active_tree] ||= []
    @sb[:history][x_active_tree]
  end

  def x_tree_init(name, type, leaf, values = {})
    return if @sb.has_key_path?(:trees, name)

    values = values.reverse_merge(
      :tree       => name,
      :type       => type,
      :leaf       => leaf,
      :add_root   => true,
      :open_nodes => []
    )

    @sb.store_path(:trees, name, values)
  end

  def x_active_tree
    @sb[:active_tree]
  end

  TREE_WHITELIST = %w"
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
    condition_tree
    customization_templates_tree
    db_tree
    diagnostics_tree
    dialog_edit_tree
    dialog_import_export_tree
    dialogs_tree
    event_tree
    export_tree
    images_filter_tree
    images_tree
    instances_filter_tree
    instances_tree
    iso_datastores_tree
    old_dialogs_tree
    ot_tree
    policy_profile_tree
    policy_tree
    pxe_image_types_tree
    pxe_servers_tree
    rbac_tree
    reports_tree
    roles_tree
    sandt_tree
    savedreports_tree
    schedules_tree
    settings_tree
    stcat_tree
    svccat_tree
    svcs_tree
    templates_filter_tree
    templates_images_filter_tree
    utilization_tree
    vandt_tree
    vmdb_tree
    vms_filter_tree
    vms_instances_filter_tree
    widgets_tree
  ".each_with_object({}) { |value, acc| acc[value] = value.to_sym }.freeze

  ACCORD_WHITELIST = %w"
    ab
    action
    alert
    alert_profile
    cb_assignments
    cb_rates
    cb_reports
    condition
    customization_templates
    db
    diagnostics
    dialog_import_export
    dialogs
    event
    export
    images
    images_filter
    instances
    instances_filter
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
  ".each_with_object({}) { |value, acc| acc[value] = value.to_sym }.freeze

  def x_active_tree=(tree)
    @sb[:active_tree] = nil
    return if tree.nil?

    raise ActionController::RoutingError, 'invalid tree' unless TREE_WHITELIST.key?(tree.to_s)
    @sb[:active_tree] = TREE_WHITELIST[tree.to_s]
  end

  def x_active_accord=(tree)
    @sb[:active_accord] = nil

    raise ActionController::RoutingError, 'invalid accordion' unless ACCORD_WHITELIST.key?(tree)
    @sb[:active_accord] = ACCORD_WHITELIST[tree]
  end

  def x_active_accord
    @sb[:active_accord]
  end

  def x_tree(tree = nil)
    tree ||= x_active_tree
    @sb.fetch_path(:trees, tree)
  end

  def x_node(tree = nil)
    tree ||= x_active_tree
    @sb.fetch_path(:trees, tree, :active_node)
  end

  def x_node=(node)
    x_node_set(node, x_active_tree)
  end

  def x_node_set(node, tree)
    @sb.store_path(:trees, tree, :active_node, node)
  end
end
