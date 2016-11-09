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
    @new_node_obj = TreeNode.new(object, parent_id, options)
  end

  attr_reader :object, :parent_id, :options

  def build_id
    @new_node_obj.key
  end

  def build
    generic_node(@new_node_obj)
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
      :key          => node.key,
      :title        => text ? text : node.title,
      :icon         => node_icon(node.image),
      :expand       => node.expand,
      :hideCheckbox => node.hide_checkbox,
      :addClass     => node.klass,
      :cfmeNoClick  => node.no_click,
      :select       => node.selected,
      :checkable    => node.checkable
    }
    tooltip(node.tooltip)
  end
end
