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
    @new_node_obj.to_h
  end
end
