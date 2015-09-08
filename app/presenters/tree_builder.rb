class TreeBuilder
  include CompressedIds
  attr_reader :name, :type, :tree_nodes

  def self.class_for_type(type)
    case type
    when :filter           then raise('Obsolete tree type.')

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

    end
  end

  def root_options
    TreeBuilder.root_options(@name)
  end

  # FIXME: need to move this to a subclass (#root_options)
  def self.root_options(tree_name)
    #returns title, tooltip, root icon
    case tree_name
    when :ab_tree                       then [_("Object Types"),                 _("Object Types")]
    when :ae_tree                       then [_("Datastore"),                    _("Datastore")]
    when :automate_tree                 then [_("Datastore"),                    _("Datastore")]
    when :bottlenecks_tree, :utilization_tree then
      if MiqEnterprise.my_enterprise.is_enterprise?
        title = _("Enterprise")
        icon  = "enterprise"
      else # FIXME: string CFME below
        title = "CFME Region: #{MiqRegion.my_region.description} [#{MiqRegion.my_region.region}]"
        icon  = "miq_region"
      end
      [title, title, icon]
    when :cb_assignments_tree           then [_("Assignments"),                    _("Assignments")]
    when :cb_rates_tree                 then [_("Rates"),                          _("Rates")]
    when :cb_reports_tree               then [_("Saved Chargeback Reports"),       _("Saved Chargeback Reports")]
    when :containers_tree               then [_("All Containers"),                 _("All Containers")]
    when :containers_filter_tree        then [_("All Containers"),                 _("All Containers")]
    when :cs_filter_tree                then
      title = "All #{ui_lookup(:ui_title => "foreman")} Configured Systems"
      [title, title]
    when :customization_templates_tree  then
      title = "All #{ui_lookup(:models => 'CustomizationTemplate')} - #{ui_lookup(:models => 'PxeImageType')}"
      [title, title]
    when :diagnostics_tree, :rbac_tree, :settings_tree     then
      region = MiqRegion.my_region
      ["CFME Region: #{region.description} [#{region.region}]", "CFME Region: #{region.description} [#{region.region}]", "miq_region"]
    when :dialogs_tree                  then [_("All Dialogs"),                  _("All Dialogs")]
    when :dialog_import_export_tree     then [_("Service Dialog Import/Export"), _("Service Dialog Import/Export")]
    when :images_tree                   then [_("Images by Provider"),           _("All Images by Provider that I can see")]
    when :instances_tree                then [_("Instances by Provider"),        _("All Instances by Provider that I can see")]
    when :instances_filter_tree         then [_("All Instances"),                _("All of the Instances that I can see")]
    when :images_filter_tree            then [_("All Images"),                   _("All of the Images that I can see")]
    when :iso_datastores_tree           then [_("All ISO Datastores"),           _("All ISO Datastores")]
    when :old_dialogs_tree              then [_("All Dialogs"),                  _("All Dialogs")]
    when :ot_tree                       then [_("All Orchestration Templates"),  _("All Orchestration Templates")]
    when :foreman_providers_tree        then
      title = "All #{ui_lookup(:ui_title => "foreman")} Providers"
      [title, title]
    when :pxe_image_types_tree          then [_("All System Image Types"),       _("All System Image Types")]
    when :pxe_servers_tree              then [_("All PXE Servers"),              _("All PXE Servers")]
    when :sandt_tree                    then [_("All Catalog Items"),            _("All Catalog Items")]
    when :stcat_tree                    then [_("All Catalogs"),                 _("All Catalogs")]
    when :svccat_tree                   then [_("All Services"),                 _("All Services")]
    when :svcs_tree                     then [_("All Services"),                 _("All Services")]
    when :vandt_tree                    then [_("All VMs & Templates"),          _("All VMs & Templates that I can see")]
    when :vms_filter_tree               then [_("All VMs"),                      _("All of the VMs that I can see")]
    when :templates_filter_tree         then [_("All Templates"),                _("All of the Templates that I can see")]
    when :vms_instances_filter_tree     then [_("All VMs & Instances"),          _("All of the VMs & Instances that I can see")]
    when :templates_images_filter_tree  then [_("All Templates & Images"),       _("All of the Templates & Images that I can see")]
    when :vmdb_tree                     then [_("VMDB"),                         _("VMDB"), "miq_database"]
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
    elsif model.nil? && [:foreman_providers_tree].include?(@name)
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
    @tree_state.x_tree(@name)[:open_nodes].push(id) unless @tree_state.x_tree(@name)[:open_nodes].include?(id)

    x_get_tree_objects(object, @tree_state.x_tree(@name), nil, parents).each_with_object([]) do |o, acc|
      acc.concat(x_build_node_dynatree(o, id, @tree_state.x_tree(@name)))
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
    model = model.to_s unless model.is_a?(String)
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
    add_root_node(nodes)
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
          :open_nodes => []
      )
    )
  end

  def add_root_node(nodes)
    root = nodes.first
    root[:title], root[:tooltip], icon = root_options
    root[:icon] = "#{icon || 'folder'}.png"
  end

  def set_locals_for_render
    {
      :tree_id        => "#{@name}box",
      :tree_name      => @name.to_s,
      :json_tree      => @tree_nodes,
      :onclick        => "miqOnClickSelectTreeNode",
      :id_prefix      => "#{@name}_",
      :base_id        => "root",
      :no_base_exp    => true,
      :exp_tree       => false,
      :highlighting   => true,
      :tree_state     => true,
      :multi_lines    => true
    }
  end

  # Build an explorer tree, from scratch
  # Options:
  # :type                   # Type of tree, i.e. :handc, :vandt, :filtered, etc
  # :leaf                   # Model name of leaf nodes, i.e. "Vm"
  # :open_nodes             # Tree node ids of currently open nodes
  # :add_root               # If true, put a root node at the top
  # :full_ids               # stack parent id on top of each node id
  def x_build_dynatree(options)
    children = x_get_tree_objects(nil, options, nil, [])

    child_nodes = children.each_with_object([]) do |child, acc|
      # already a node? FIXME: make a class for node
      if child.kind_of?(Hash) && child.key?(:title) && child.key?(:key) && child.key?(:icon)
        acc << child
      else
        acc.concat(x_build_node_dynatree(child, nil, options))
      end
    end

    return child_nodes unless options[:add_root]
    [{:key => 'root', :children => child_nodes, :expand => true}]
  end

  # Get objects (or count) to put into a tree under a parent node.
  # TODO: Perhaps push the object sorting down to SQL, if possible -- no point where there are few items.
  # parent  --- Parent object for which we need child tree nodes returned
  # options --- Options:
  #   :count_only           # Return only the count if true -- remove this
  #   :leaf                 # Model name of leaf nodes, i.e. "Vm"
  #   :open_all             # if true open all node (no autoload)
  #   :load_children
  # parents --- an Array of parent object ids, starting from tree root + 1, ending with parent's parent; only available when full_ids and not lazy
  def x_get_tree_objects(parent, options, count_only = false, parents = [])
    # FIXME: To limit the use of options and make mandatory arguments explitic,
    # we need to fix all the callers and functions to pass count_only as an
    # argument and not part of options.; same for parents
    count_only = options[:count_only] if options[:count_only]
    options = options.dup
    options[:count_only] = count_only
    options[:parents] = parents

    children_or_count = case parent
                        when nil                 then x_get_tree_roots(options)
                        when AvailabilityZone    then x_get_tree_az_kids(parent, options)
                        when ManageIQ::Providers::Foreman::ConfigurationManager then x_get_tree_cmf_kids(parent, options)
                        when ConfigurationProfile then x_get_tree_cpf_kids(parent, options)
                        when CustomButtonSet     then x_get_tree_aset_kids(parent, options)
                        when Dialog              then x_get_tree_dialog_kids(parent, options)
                        when DialogGroup         then x_get_tree_dialog_group_kids(parent, options)
                        when DialogTab           then x_get_tree_dialog_tab_kids(parent, options)
                        when ExtManagementSystem then x_get_tree_ems_kids(parent, options)
                        when EmsFolder           then if parent.is_datacenter
                                                        x_get_tree_datacenter_kids(parent, options)
                                                      else
                                                        x_get_tree_folder_kids(parent, options)
                                                      end
                        when EmsCluster          then x_get_tree_cluster_kids(parent, options)
                        when Hash                then x_get_tree_custom_kids(parent, options)
                        when IsoDatastore        then x_get_tree_iso_datastore_kids(parent, options)
                        when LdapRegion          then x_get_tree_lr_kids(parent, options)
                        when MiqAeClass          then x_get_tree_class_kids(parent, options)
                        when MiqAeNamespace      then x_get_tree_ns_kids(parent, options)
                        when MiqGroup            then options[:tree] == :db_tree ?
                                                    x_get_tree_g_kids(parent, options) : nil
                        when MiqRegion           then x_get_tree_region_kids(parent, options)
                        when PxeServer           then x_get_tree_pxe_server_kids(parent, options)
                        when Service             then x_get_tree_service_kids(parent, options)
                        when ServiceTemplateCatalog
                                                 then x_get_tree_stc_kids(parent, options)
                        when ServiceTemplate     then x_get_tree_st_kids(parent, options)
                        when Tenant              then x_get_tree_tenant_kids(parent, options)
                        when VmdbTableEvm        then x_get_tree_vmdb_table_kids(parent, options)
                        when Zone                then x_get_tree_zone_kids(parent, options)

                        when MiqPolicySet        then x_get_tree_pp_kids(parent, options)
                        when MiqAction           then x_get_tree_ac_kids(parent, options)
                        when MiqAlert            then x_get_tree_al_kids(parent, options)
                        when MiqAlertSet         then x_get_tree_ap_kids(parent, options)
                        when Condition           then x_get_tree_co_kids(parent, options)
                        when MiqEventDefinition  then x_get_tree_ev_kids(parent, options)
                        when MiqPolicy           then x_get_tree_po_kids(parent, options)

                        when MiqSearch           then nil
                        when ManageIQ::Providers::Openstack::CloudManager::Vm         then nil
                        else                          nil end
    children_or_count || (count_only ? 0 : [])
  end

  # Return a tree node for the passed in object
  def x_build_node(object, pid, options)    # Called with object, tree node parent id, tree options
    parents = pid.to_s.split('_')

    options[:is_current] =
        ((object.kind_of?(MiqServer) && MiqServer.my_server(true).id == object.id) ||
         (object.kind_of?(Zone)      && MiqServer.my_server(true).my_zone == object.name))

    # # open nodes to show selected automate entry point
    # x_tree[:open_nodes] = @temp[:open_nodes].dup if @temp && @temp[:open_nodes]
    # x_tree[:open_nodes] = @open_nodes.dup if @open_nodes

    node = x_build_single_node(object, pid, options)

    if [:policy_profile_tree, :policy_tree].include?(options[:tree])
      @tree_state.x_tree(@name)[:open_nodes].push(node[:key])
    end

    # Process the node's children
    if Array(@tree_state.x_tree(@name)[:open_nodes]).include?(node[:key]) ||
       options[:open_all] ||
       object[:load_children] ||
       node[:expand]
      kids = x_get_tree_objects(object, options, nil, parents).each_with_object([]) do |o, acc|
        acc.concat(x_build_node(o, node[:key], options))
      end
      node[:children] = kids unless kids.empty?
    else
      if x_get_tree_objects(object, options.merge(:count_only => true), nil, parents) > 0
        node[:isLazy] = true  # set child flag if children exist
      end
    end
    [node]
  end

  def x_build_single_node(object, pid, options)
    TreeNodeBuilder.build(object, pid, options)
  end

  # Called with object, tree node parent id, tree options
  def x_build_node_dynatree(object, pid, options)
    x_build_node(object, pid, options)
  end

  # Handle custom tree nodes (object is a Hash)
  def x_get_tree_custom_kids(object, options)
    options[:count_only] ? 0 : []
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

  def get_vmdb_config
    @vmdb_config ||= VMDB::Config.new("vmdb").config
  end

  def rbac_filtered_objects(objects, options = {})
    self.class.rbac_filtered_objects(objects, options)
  end

  # Add child nodes to the active tree below node 'id'
  def self.tree_add_child_nodes(sandbox, klass_name, id)
    tree = klass_name.constantize.new(sandbox[:active_tree].to_s,
                                      sandbox[:active_tree].to_s.sub(/_tree$/, ''),
                                      sandbox, false)
    tree.x_get_child_nodes(id)
  end

  def self.rbac_filtered_objects(objects, options = {})
    return objects if objects.empty?

    # Remove VmOrTemplate :match_via_descendants option if present, comment to let Rbac.search process it
    check_vm_descendants = false
    check_vm_descendants = options.delete(:match_via_descendants) if options[:match_via_descendants] == "VmOrTemplate"

    results = Rbac.filtered(objects, options)

    # If we are processing :match_via_descendants and user is filtered (i.e. not like admin/super-admin)
    if check_vm_descendants && User.current_user_has_filters?
      filtered_objects = objects - results
      results = objects.select do |o|
        if o.is_a?(EmsFolder) || filtered_objects.include?(o)
          rbac_has_visible_vm_descendants?(o)
        else
          true
        end
      end
    end

    results
  end

  def self.rbac_has_visible_vm_descendants?(o)
    target_ids = o.descendant_ids(:of_type => "VmOrTemplate").transpose.last
    return false if target_ids.blank?
    results, _attrs = Rbac.search(:targets => target_ids, :class => VmOrTemplate)
    results.length > 0
  end
  private_class_method :rbac_has_visible_vm_descendants?

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
    "cnt" => "Container",
    "co"  => "Condition",
    "cbg" => "CustomButtonSet",
    "cb"  => "CustomButton",
    "cfn" => "OrchestrationTemplateCfn",
    "cp"  => "ConfigurationProfile",
    "cr"  => "ChargebackRate",
    "cs"  => "ConfiguredSystem",
    "ct"  => "CustomizationTemplate",
    "d"   => "Datacenter",
    "dg"  => "Dialog",
    "ds"  => "Storage",
    "e"   => "ExtManagementSystem",
    "ev"  => "MiqEventDefinition",
    "c"   => "EmsCluster",
    "f"   => "EmsFolder",
    "g"   => "MiqGroup",
    "h"   => "Host",
    "hot" => "OrchestrationTemplateHot",
    "isd" => "IsoDatastore",
    "isi" => "IsoImage",
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
    "sis" => "ScanItemSet",
    "st"  => "ServiceTemplate",
    "stc" => "ServiceTemplateCatalog",
    "sr"  => "ServiceResource",
    "t"   => "MiqTemplate",
    "tb"  => "VmdbTable",
    "ti"  => "VmdbIndex",
    "tn"  => "Tenant",
    "u"   => "User",
    "v"   => "Vm",
    "wi"  => "WindowsImage",
    "xx"  => "Hash",  # For custom (non-CI) nodes, specific to each tree
    "z"   => "Zone"
  }

  X_TREE_NODE_PREFIXES_INVERTED = X_TREE_NODE_PREFIXES.invert
end
