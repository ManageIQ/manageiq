class TreeBuilder
  include CompressedIds
  include TreeKids

  attr_reader :name, :type, :tree_nodes

  def node_builder
    TreeNodeBuilder
  end
  def self.class_for_type(type)
    case type
    when :filter           then raise('Obsolete tree type.')
    # Catalog explorer trees
    when :configuration_manager_providers then TreeBuilderConfigurationManager
    when :cs_filter                       then TreeBuilderConfigurationManagerConfiguredSystems
    when :configuration_scripts           then TreeBuilderConfigurationManagerConfigurationScripts

    # Catalog explorer trees
    when :ot               then TreeBuilderOrchestrationTemplates
    when :sandt            then TreeBuilderCatalogItems
    when :stcat            then TreeBuilderCatalogs
    when :svccat           then TreeBuilderServiceCatalog

    # Chargeback explorer trees
    when :cb_assignments   then TreeBuilderChargebackAssignments
    when :cb_rates         then TreeBuilderChargebackRates
    when :cb_reports       then TreeBuilderChargebackReports

    when :vandt            then TreeBuilderVandt
    when :vms_filter       then TreeBuilderVmsFilter
    when :templates_filter then TreeBuilderTemplateFilter

    when :instances        then TreeBuilderInstances
    when :images           then TreeBuilderImages
    when :instances_filter then TreeBuilderInstancesFilter
    when :images_filter    then TreeBuilderImagesFilter
    when :vms_instances_filter    then TreeBuilderVmsInstancesFilter
    when :templates_images_filter then TreeBuilderTemplatesImagesFilter

    when :policy_profile   then TreeBuilderPolicyProfile
    when :policy           then TreeBuilderPolicy
    when :event            then TreeBuilderEvent
    when :condition        then TreeBuilderCondition
    when :action           then TreeBuilderAction
    when :alert_profile    then TreeBuilderAlertProfile
    when :alert            then TreeBuilderAlert

    # reports explorer trees
    when :db               then TreeBuilderReportDashboards
    when :export           then TreeBuilderReportExport
    when :reports          then TreeBuilderReportReports
    when :roles            then TreeBuilderReportRoles
    when :savedreports     then TreeBuilderReportSavedReports
    when :schedules        then TreeBuilderReportSchedules
    when :widgets          then TreeBuilderReportWidgets

    # containers explorer tree
    when :containers         then TreeBuilderContainers
    when :containers_filter  then TreeBuilderContainersFilter

    # automate explorer tree
    when :ae               then TreeBuilderAeClass

    # miq_ae_customization explorer trees
    when :ab                    then TreeBuilderButtons
    when :dialogs               then TreeBuilderServiceDialogs
    when :dialog_import_export  then TreeBuilderAeCustomization
    when :old_dialogs           then TreeBuilderProvisioningDialogs

    # OPS explorer trees
    when :diagnostics           then TreeBuilderOpsDiagnostics
    when :rbac                  then TreeBuilderOpsRbac
    when :settings              then TreeBuilderOpsSettings
    when :vmdb                  then TreeBuilderOpsVmdb

    # PXE explorer trees
    when :customization_templates then TreeBuilderPxeCustomizationTemplates
    when :iso_datastores          then TreeBuilderIsoDatastores
    when :pxe_image_types         then TreeBuilderPxeImageTypes
    when :pxe_servers             then TreeBuilderPxeServers

    # Services explorer tree
    when :svcs                    then TreeBuilderServices

    when :sa                      then TreeBuilderStorageAdapters

    # Datastores explorer trees
    when :storage     then TreeBuilderStorage
    when :storage_pod then TreeBuilderStoragePod

    when :datacenter              then TreeBuilderDatacenter
    when :vat                     then TreeBuilderVat

    when :network                 then TreeBuilderNetwork
    when :df                      then TreeBuilderDefaultFilters
    end
  end

  def initialize(name, type, sandbox, build = true)
    @tree_state = TreeState.new(sandbox)
    @sb = sandbox # FIXME: some subclasses still access @sb

    @locals_for_render  = {}
    @name               = name.to_sym                     # includes _tree
    @options            = tree_init_options(name.to_sym)
    @tree_nodes         = {}.to_json
    # FIXME: remove @name or @tree, unify
    @type               = type.to_sym                     # *usually* same as @name but w/o _tree

    add_to_sandbox
    build_tree if build
  end

  def node_by_tree_id(id)
    model, rec_id, prefix = self.class.extract_node_model_and_id(id)

    if model == "Hash"
      {:type => prefix, :id => rec_id, :full_id => id}
    elsif model.nil? && [:sandt, :svccat, :stcat].include?(@type)
      # Creating empty record to show items under unassigned catalog node
      ServiceTemplateCatalog.new
    elsif model.nil? && [:configuration_manager_providers_tree].include?(@name)
      # Creating empty record to show items under unassigned catalog node
      ConfigurationProfile.new
    else
      model.constantize.find(from_cid(rec_id))
    end
  end

  # Get the children of a dynatree node that is being expanded (autoloaded)
  def x_get_child_nodes(id)
    parents = [] # FIXME: parent ids should be provided on autoload as well

    object = node_by_tree_id(id)

    # Save node as open
    open_node(id)

    x_get_tree_objects(object, @tree_state.x_tree(@name), false, parents).map do |o|
      x_build_node_dynatree(o, id, @tree_state.x_tree(@name))
    end
  end

  def tree_init_options(_tree_name)
    $log.warn "MIQ(#{self.class.name}) - TreeBuilder descendants should have their own tree_init_options"
    {}
  end

  # Get nodes model (folder, Vm, Cluster, etc)
  def self.get_model_for_prefix(node_prefix)
    X_TREE_NODE_PREFIXES[node_prefix]
  end

  def self.get_prefix_for_model(model)
    model = model.to_s unless model.kind_of?(String)
    X_TREE_NODE_PREFIXES_INVERTED[model]
  end

  def self.build_node_id(record)
    prefix = get_prefix_for_model(record.class.base_model)
    "#{prefix}-#{record.id}"
  end

  # return this nodes model and record id
  def self.extract_node_model_and_id(node_id)
    prefix, record_id = node_id.split("_").last.split('-')
    model = get_model_for_prefix(prefix)
    [model, record_id, prefix]
  end

  def locals_for_render
    @locals_for_render.update(:select_node => "#{@tree_state.x_node(@name)}")
  end

  def reload!
    build_tree
  end

  private

  def build_tree
    # FIXME: we have the options -- no need to reload from @sb
    tree_nodes = x_build_dynatree(@tree_state.x_tree(@name))
    active_node_set(tree_nodes)
    set_nodes(tree_nodes)
  end

  # Set active node to root if not set.
  # Subclass this method if active node on initial load is different than root node.
  def active_node_set(tree_nodes)
    @tree_state.x_node_set(tree_nodes.first[:key], @name) unless @tree_state.x_node(@name)
  end

  def set_nodes(nodes)
    # Add the root node even if it is not set
    add_root_node(nodes) if @options.fetch(:add_root, :true)
    @tree_nodes = nodes.to_json
    @locals_for_render = set_locals_for_render
  end

  def add_to_sandbox
    @tree_state.add_tree(
      @options.reverse_merge(
        :tree       => @name,
        :type       => type,
        :klass_name => self.class.name,
        :leaf       => @options[:leaf],
        :add_root   => true,
        :open_nodes => [],
        :lazy       => true
      )
    )
  end

  def add_root_node(nodes)
    root = nodes.first
    root[:title], root[:tooltip], icon, options = root_options
    root[:icon] = ActionController::Base.helpers.image_path("100/#{icon || 'folder'}.png")
    root[:cfmeNoClick] = options[:cfmeNoClick] if options.present? && options.key?(:cfmeNoClick)
  end

  def set_locals_for_render
    {
      :tree_id      => "#{@name}box",
      :tree_name    => @name.to_s,
      :json_tree    => @tree_nodes,
      :onclick      => "miqOnClickSelectTreeNode",
      :id_prefix    => "#{@name}_",
      :base_id      => "root",
      :no_base_exp  => true,
      :exp_tree     => false,
      :highlighting => true,
      :tree_state   => true,
      :multi_lines  => true,
      :checkboxes   => false,
    }
  end

  # Build an explorer tree, from scratch
  # Options:
  # :type                   # Type of tree, i.e. :handc, :vandt, :filtered, etc
  # :leaf                   # Model name of leaf nodes, i.e. "Vm"
  # :open_nodes             # Tree node ids of currently open nodes
  # :add_root               # If true, put a root node at the top
  # :full_ids               # stack parent id on top of each node id
  # :lazy                   # set if tree is lazy
  def x_build_dynatree(options)
    children = x_get_tree_objects(nil, options, false, [])

    child_nodes = children.map do |child|
      # already a node? FIXME: make a class for node
      if child.kind_of?(Hash) && child.key?(:title) && child.key?(:key) && child.key?(:icon)
        child
      else
        x_build_node_dynatree(child, nil, options)
      end
    end
    return child_nodes unless options[:add_root]
    [{:key => 'root', :children => child_nodes, :expand => true}]
  end

  def x_get_tree_objects(parent, options, count_only, parents)
    children_or_count = parent.nil? ? x_get_tree_roots(count_only, options) : x_get_tree_kids(parent, count_only, options, parents)
    children_or_count || (count_only ? 0 : [])
  end

  # Return a tree node for the passed in object
  def x_build_node(object, pid, options)    # Called with object, tree node parent id, tree options
    parents = pid.to_s.split('_')

    options[:is_current] =
        ((object.kind_of?(MiqServer) && MiqServer.my_server(true).id == object.id) ||
         (object.kind_of?(Zone) && MiqServer.my_server(true).my_zone == object.name))

    node = x_build_single_node(object, pid, options)

    if [:policy_profile_tree, :policy_tree].include?(options[:tree])
      open_node(node[:key])
    end

    # Process the node's children
    if Array(@tree_state.x_tree(@name)[:open_nodes]).include?(node[:key]) ||
       options[:open_all] ||
       object[:load_children] ||
       node[:expand] ||
       @options[:lazy] == false
      node[:expand] = true if options[:type] == :automate &&
                              Array(@tree_state.x_tree(@name)[:open_nodes]).include?(node[:key])
      kids = x_get_tree_objects(object, options, false, parents).map do |o|
        x_build_node(o, node[:key], options)
      end
      node[:children] = kids unless kids.empty?
    else
      if x_get_tree_objects(object, options, true, parents) > 0
        node[:isLazy] = true  # set child flag if children exist
      end
    end
    node
  end

  def x_build_single_node(object, pid, options)
    node_builder.build(object, pid, options)
  end

  # Called with object, tree node parent id, tree options
  def x_build_node_dynatree(object, pid, options)
    x_build_node(object, pid, options)
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(_object, count_only, _options)
    count_only ? 0 : []
  end

  def count_only_or_objects(count_only, objects, sort_by = nil)
    if count_only
      objects.size
    elsif sort_by.kind_of?(Proc)
      objects.sort_by(&sort_by)
    elsif sort_by
      objects.sort_by { |o| Array(sort_by).collect { |sb| o.deep_send(sb).to_s.downcase } }
    else
      objects
    end
  end

  def assert_type(actual, expected)
    raise "#{self.class}: expected #{expected.inspect}, got #{actual.inspect}" unless actual == expected
  end

  def open_node(id)
    open_nodes = @tree_state.x_tree(@name)[:open_nodes]
    open_nodes.push(id) unless open_nodes.include?(id)
  end

  def get_vmdb_config
    @vmdb_config ||= VMDB::Config.new("vmdb").config
  end

  def rbac_filtered_objects(objects, options = {})
    Rbac.filtered(objects, options)
  end

  # Add child nodes to the active tree below node 'id'
  def self.tree_add_child_nodes(sandbox, klass_name, id)
    tree = klass_name.constantize.new(sandbox[:active_tree].to_s,
                                      sandbox[:active_tree].to_s.sub(/_tree$/, ''),
                                      sandbox, false)
    tree.x_get_child_nodes(id)
  end

  def self.rbac_filtered_objects(objects, options = {})
    Rbac.filtered(objects, options)
  end

  def self.rbac_has_visible_descendants?(o, type)
    target_ids = o.descendant_ids(:of_type => type).transpose.last
    !target_ids.nil? && Rbac.filtered(target_ids, :class => type.constantize).present?
  end
  private_class_method :rbac_has_visible_descendants?

  # Tree node prefixes for generic explorers
  X_TREE_NODE_PREFIXES = {
    "a"   => "MiqAction",
    "aec" => "MiqAeClass",
    "aei" => "MiqAeInstance",
    "aem" => "MiqAeMethod",
    "aen" => "MiqAeNamespace",
    "al"  => "MiqAlert",
    "ap"  => "MiqAlertSet",
    "az"  => "AvailabilityZone",
    "azu" => "OrchestrationTemplateAzure",
    "at"  => "ManageIQ::Providers::AnsibleTower::ConfigurationManager",
    "cf " => "ConfigurationScript",
    "cnt" => "Container",
    "co"  => "Condition",
    "cbg" => "CustomButtonSet",
    "cb"  => "CustomButton",
    "cfn" => "OrchestrationTemplateCfn",
    "cm"  => "Compliance",
    "cd"  => "ComplianceDetail",
    "cp"  => "ConfigurationProfile",
    "cr"  => "ChargebackRate",
    "cs"  => "ConfiguredSystem",
    "ct"  => "CustomizationTemplate",
    "dc"  => "Datacenter",
    "dg"  => "Dialog",
    "ds"  => "Storage",
    "dsc" => "StorageCluster",
    "e"   => "ExtManagementSystem",
    "ev"  => "MiqEventDefinition",
    "c"   => "EmsCluster",
    "csf" => "ManageIQ::Providers::Foreman::ConfigurationManager::ConfiguredSystem",
    "csa" => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfiguredSystem",
    "f"   => "EmsFolder",
    "fr"  => "ManageIQ::Providers::Foreman::ConfigurationManager",
    "g"   => "MiqGroup",
    "gd"  => "GuestDevice",
    "h"   => "Host",
    "hot" => "OrchestrationTemplateHot",
    "isd" => "IsoDatastore",
    "isi" => "IsoImage",
    "l"   => "Lan",
    "ld"  => "LdapDomain",
    "lr"  => "LdapRegion",
    "me"  => "MiqEnterprise",
    "mr"  => "MiqRegion",
    "msc" => "MiqSchedule",
    "ms"  => "MiqSearch",
    "odg" => "MiqDialog",
    "ot"  => "OrchestrationTemplate",
    "pi"  => "PxeImage",
    "pit" => "PxeImageType",
    "ps"  => "PxeServer",
    "pp"  => "MiqPolicySet",
    "p"   => "MiqPolicy",
    "rep" => "MiqReport",
    "rr"  => "MiqReportResult",
    "svr" => "MiqServer",
    "ur"  => "MiqUserRole",
    "r"   => "ResourcePool",
    "s"   => "Service",
    "sa"  => "StorageAdapter",
    'sn'  => 'Snapshot',
    "sl"  => "MiqScsiLun",
    "sg"  => "MiqScsiTarget",
    "sis" => "ScanItemSet",
    "st"  => "ServiceTemplate",
    "stc" => "ServiceTemplateCatalog",
    "sr"  => "ServiceResource",
    "sw"  => "Switch",
    "t"   => "MiqTemplate",
    "tb"  => "VmdbTable",
    "ti"  => "VmdbIndex",
    "tn"  => "Tenant",
    "u"   => "User",
    "v"   => "Vm",
    "vnf" => "OrchestrationTemplateVnfd",
    "wi"  => "WindowsImage",
    "xx"  => "Hash",  # For custom (non-CI) nodes, specific to each tree
    "z"   => "Zone"
  }

  X_TREE_NODE_PREFIXES_INVERTED = X_TREE_NODE_PREFIXES.invert
end
