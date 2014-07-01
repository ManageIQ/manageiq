# TODO: FullTreeBuilder is subclassing TreeBuilder pretty much only for the
#   x_build_single_node method.  Ultimately, the TreeBuilder should become a
#   WalkingTreeBuilder class, and a new base class of TreeBuilder should be
#   made that only does the conversion to UI nodes.
#
#   TreeBuilder
#   +- FullTreeBuilder
#   |  \- TreeBuilderVmsAndTemplates
#   \- WalkingTreeBuilder (current TreeBuilder)
#      \- TreeBuilderServices
class FullTreeBuilder < TreeBuilder
  attr_accessor :root, :options

  def initialize(root, options = {})
    @root    = root
    @options = options
  end

  def tree
    convert_to_ui_tree(relationship_tree)
  end

  private

  # Recursively create the UI tree from a Relationship tree
  #
  # @param rel_tree [Hash] the Hash based Relationship tree to convert, with
  #   key/value pairs in the form `ActiveRecord::Base (object) => Hash (children)`
  # @param parent_ui_tree_id [String] the UI tree id of the parent.  This value
  #   is used in the recursion and should not be passed for the root of the tree.
  # @return [Hash] the UI data as a nested Hash structure
  def convert_to_ui_tree(rel_tree, parent_ui_tree_id = nil)
    ui_tree = rel_tree.collect do |object, children|
      ui_node = x_build_single_node(object, parent_ui_tree_id, options)

      unless children.blank?
        ui_node[:children] = convert_to_ui_tree(children, ui_node[:key])
      end

      ui_node
    end

    parent_ui_tree_id.nil? ? ui_tree.first : ui_tree
  end
end
