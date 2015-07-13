class TreeState
  include Sandbox

  def initialize(sandbox)
    @sb = sandbox
  end

  def add_tree(tree_params)
    name = tree_params[:tree]
    return false if @sb.has_key_path?(:trees, name)
    @sb.store_path(:trees, name, tree_params)
  end
end
