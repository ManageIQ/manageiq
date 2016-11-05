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
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
      @node[:addClass] = new_node_obj.klass
    },
    "AvailabilityZone"       => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ConfigurationScript"    => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ExtManagementSystem"    => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ChargebackRate"         => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Classification"         => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
      @node[:cfmeNoClick] = !new_node_obj.click
      @node[:hideCheckbox] = !new_node_obj.checkbox
    },
    "Compliance"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ComplianceDetail"       => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Condition"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ConfigurationProfile"   => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ConfiguredSystem"       => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Container"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "CustomButton"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "CustomButtonSet"        => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "CustomizationTemplate"  => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Dialog"                 => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "DialogTab"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "DialogGroup"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "DialogField"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "EmsFolder"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "EmsCluster"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "GuestDevice"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Host"                   => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "IsoDatastore"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "IsoImage"               => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ResourcePool"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Lan"                    => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "LdapDomain"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "LdapRegion"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqAeClass"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqAeInstance"          => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqAeMethod"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqAeNamespace"         => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
      @node[:addClass] = new_node_obj.klass
    },
    "MiqAlertSet"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqReport"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqReportResult"        => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
      @node[:expand] ||= new_node_obj.expand
    },
    "MiqSchedule"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqScsiLun"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqScsiTarget"          => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqServer"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
      @node[:expand] ||= new_node_obj.expand
    },
    "MiqAlert"               => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqAction"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqEventDefinition"     => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqGroup"               => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqPolicy"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqPolicySet"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqUserRole"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "OrchestrationTemplate"  => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "PxeImage"               => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "WindowsImage"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "PxeImageType"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "PxeServer"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ScanItemSet"            => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Service"                => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ServiceResource"        => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ServerRole"             => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
      @node[:expand] ||= new_node_obj.expand
    },
    "ServiceTemplate"        => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "ServiceTemplateCatalog" => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Snapshot"               => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
      if (options[:selected_node].present? && @node[:key] == options[:selected_node]) || object.children.empty?
        @node[:highlighted] = true
      end
    },
    "Storage"                => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Switch"                 => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "User"                   => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqSearch"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqDialog"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqRegion"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
      @node[:expand] ||= new_node_obj.expand
    },
    "MiqWidget"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "MiqWidgetSet"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Tenant"                 => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "VmdbTable"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "VmdbIndex"              => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "VmOrTemplate"           => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
    },
    "Zone"                   => -> {
      new_node_obj = TreeNode.new(object, parent_id, options)
      generic_node(new_node_obj.title, new_node_obj.image, new_node_obj.tooltip)
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

  def generic_node(text, image, tip = nil)
    text = ERB::Util.html_escape(text ? URI.unescape(text) : text) unless text.html_safe?
    @node = {
      :key   => build_object_id,
      :title => text,
      :icon  => node_icon(image)
    }
    # Start with all nodes open unless expand is explicitly set to false
    @node[:expand] = options[:open_all].present? && options[:open_all] && options[:expand] != false
    @node[:hideCheckbox] = options[:hideCheckbox] if options[:hideCheckbox].present?
    tooltip(tip)
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
