class TreeNodeBuilder
  include MiqAeClassHelper

  # method to build non-explorer tree nodes
  def self.generic_tree_node(key, text, image, tip = nil, options = {})
    text = ERB::Util.html_escape(text) unless text.html_safe?
    node = {
      :key   => key,
      :title => text,
    }
    node[:icon]         = ActionController::Base.helpers.image_path("100/#{image}") if image
    node[:addClass]     = options[:style_class]      if options[:style_class]
    node[:cfmeNoClick]  = true                       if options[:cfme_no_click]
    node[:expand]       = options[:expand]           if options[:expand]
    node[:hideCheckbox] = true                       if options[:hideCheckbox]
    node[:noLink]       = true                       if options[:noLink]
    node[:select]       = options[:select]           if options[:select]
    node[:tooltip]      = ERB::Util.html_escape(tip) if tip && !tip.html_safe?
    node
  end

  # Options used:
  #   :type       -- Type of tree, i.e. :handc, :vandt, :filtered, etc
  #   :open_nodes -- Tree node ids of currently open nodes
  #   FIXME: fill in missing docs
  #
  def self.build(object, parent_id, options)
    builder = new(object, parent_id, options)
    builder.build
  end

  def self.build_id(object, parent_id, options)
    builder = new(object, parent_id, options)
    builder.build_id
  end

  def initialize(object, parent_id, options)
    @object, @parent_id, @options = object, parent_id, options
  end

  attr_reader :object, :parent_id, :options

  def build_id
    object.kind_of?(Hash) ? build_hash_id : build_object_id
  end

  # FIXME: This is a rubocop disaster... fixed the alignment with the params,
  # but that is about as far as I was willing to go with this one...
  #
  # rubocop:disable LineLength, Style/BlockDelimiters, Style/BlockEndNewline
  # rubocop:disable Style/Lambda, Style/AlignParameters, Style/MultilineBlockLayout
  BUILD_NODE_HASH = {
    "AssignedServerRole"     => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "AvailabilityZone"       => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ConfigurationScript"    => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ExtManagementSystem"    => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ChargebackRate"         => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Classification"         => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Compliance"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ComplianceDetail"       => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Condition"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ConfigurationProfile"   => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ConfiguredSystem"       => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Container"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "CustomButton"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "CustomButtonSet"        => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "CustomizationTemplate"  => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Dialog"                 => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "DialogTab"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "DialogGroup"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "DialogField"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "EmsFolder"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "EmsCluster"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "GuestDevice"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Host"                   => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "IsoDatastore"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "IsoImage"               => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ResourcePool"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Lan"                    => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "LdapDomain"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "LdapRegion"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqAeClass"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqAeInstance"          => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqAeMethod"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqAeNamespace"         => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqAlertSet"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqReport"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqReportResult"        => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqSchedule"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqScsiLun"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqScsiTarget"          => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqServer"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqAlert"               => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqAction"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqEventDefinition"     => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqGroup"               => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqPolicy"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqPolicySet"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqUserRole"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "OrchestrationTemplate"  => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "PxeImage"               => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "WindowsImage"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "PxeImageType"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "PxeServer"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ScanItemSet"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Service"                => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ServiceResource"        => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ServerRole"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ServiceTemplate"        => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "ServiceTemplateCatalog" => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Snapshot"               => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
      if (options[:selected_node].present? && @node[:key] == options[:selected_node]) || object.children.empty?
        @node[:highlighted] = true
      end
    },
    "Storage"                => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Switch"                 => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "User"                   => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqSearch"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqDialog"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqRegion"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqWidget"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "MiqWidgetSet"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Tenant"                 => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "VmdbTable"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "VmdbIndex"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "VmOrTemplate"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Zone"                   => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj)
    },
    "Hash"                   => -> {
      hash_node
    },
  }.freeze
  # rubocop:enable all

  def build
    # If this is a Decorator, then move grab it's `.object` since we will want
    # to lookup based on that.
    obj = object.kind_of?(Draper::Decorator) ? object.object : object

    # Find the proc for the class either based on it's class name, or it's
    # `base_class` (the top level of the inheritence tree)
    node_lambda =   BUILD_NODE_HASH[obj.class.name]
    node_lambda ||= BUILD_NODE_HASH[obj.class.base_class.to_s]

    # Execute the proc from the BUILD_NODE_HASH in the context of the instance
    instance_exec(&node_lambda) if node_lambda
    @node
  end

  private

  def tooltip(tip)
    unless tip.blank?
      tip = tip.kind_of?(Proc) ? tip.call : _(tip)
      tip = ERB::Util.html_escape(URI.unescape(tip)) unless tip.html_safe?
      @node[:tooltip] = tip
    end
  end

  def node_icon(icon)
    if icon.start_with?("/")
      icon
    elsif icon =~ %r{^[a-zA-Z0-9]+/}
      ActionController::Base.helpers.image_path(icon)
    else
      ActionController::Base.helpers.image_path("100/#{icon}")
    end
  end

  def generic_node(node)
    text = ERB::Util.html_escape(node.title ? URI.unescape(node.title) : node.title) unless node.title.html_safe?
    @node = {
      :key          => build_object_id,
      :title        => text ? text : node.title,
      :icon         => node_icon(node.image),
      :expand       => node.expand,
      :hideCheckbox => node.hide_checkbox,
      :addClass     => node.klass,
      :cfmeNoClick  => node.no_click
    }
    tooltip(node.tooltip)
  end

  def hash_node
    text = object[:text]
    text = text.kind_of?(Proc) ? text.call : _(text)

    # FIXME: expansion
    @node = {
      :key   => build_hash_id,
      :title => ERB::Util.html_escape(text)
    }
    @node[:icon] = node_icon("#{object[:image] || text}.png") if object[:image]
    # Start with all nodes open unless expand is explicitly set to false
    @node[:expand] = true if options[:open_all] && options[:expand] != false
    @node[:cfmeNoClick] = object[:cfmeNoClick] if object.key?(:cfmeNoClick)
    @node[:hideCheckbox] = true if object.key?(:hideCheckbox)
    @node[:select] = object[:select] if object.key?(:select)
    @node[:addClass] = object[:addClass] if object.key?(:addClass)
    @node[:checkable] = object[:checkable] if object.key?(:checkable)

    # FIXME: check the following
    # TODO: With dynatree, unless folders are open, we can't jump to a child node until it has been visible once
    # node[:expand] = false

    tooltip(object[:tip])
  end

  def format_parent_id
    (options[:full_ids] && !parent_id.blank?) ? "#{parent_id}_" : ''
  end

  def build_hash_id
    if object[:id] == "-Unassigned"
      "-Unassigned"
    else
      prefix = TreeBuilder.get_prefix_for_model("Hash")
      "#{format_parent_id}#{prefix}-#{object[:id]}"
    end
  end

  def build_object_id
    if object.id.nil?
      # FIXME: this makes problems in tests
      # to handle "Unassigned groups" node in automate buttons tree
      "-#{object.name.split('|').last}"
    else
      base_class = object.class.base_model.name           # i.e. Vm or MiqTemplate
      base_class = "Datacenter" if base_class == "EmsFolder" && object.kind_of?(Datacenter)
      base_class = "ManageIQ::Providers::Foreman::ConfigurationManager" if object.kind_of?(ManageIQ::Providers::Foreman::ConfigurationManager)
      base_class = "ManageIQ::Providers::AnsibleTower::ConfigurationManager" if object.kind_of?(ManageIQ::Providers::AnsibleTower::ConfigurationManager)
      prefix = TreeBuilder.get_prefix_for_model(base_class)
      cid = ApplicationRecord.compress_id(object.id)
      "#{format_parent_id}#{prefix}-#{cid}"
    end
  end
end
