module ApplicationController::TreeSupport
  extend ActiveSupport::Concern

  def squash_toggle
    @record = find_record
    item = "h_#{@record.name}"
    render :update do |page|
      page << javascript_prologue
      if session[:squash_open] == false
        page << "$('#squash_img i').attr('class','fa fa-angle-double-up fa-lg')"
        page << "$('#squash_img').prop('title', 'Collapse All')"
        page << "miqTreeToggleExpand('#{j_str(session[:tree_name])}', true)"
        session[:squash_open] = true
      else
        page << "$('#squash_img i').attr('class','fa fa-angle-double-down fa-lg')"
        page << "$('#squash_img').prop('title', 'Expand All')"
        page << "miqTreeToggleExpand('#{j_str(session[:tree_name])}', false);"
        page << "miqTreeActivateNodeSilently('#{j_str(session[:tree_name])}', '#{item}');"
        session[:squash_open] = false
      end
    end
  end

  def find_record
    # TODO: This logic should probably be reversed - fixed list for VmOrTemplate.
    # (Better yet, override the method only in VmOrTemplate related controllers.)
    if %w(host container_replicator container_group container_node container_image ext_management_system).include? controller_name
      identify_record(params[:id], controller_name.classify)
    else
      identify_record(params[:id], VmOrTemplate)
    end
  end

  def tree_autoload
    @edit ||= session[:edit] # Remember any previous @edit
    render :json => tree_add_child_nodes(params[:id])
  end

  def tree_add_child_nodes(id)
    tree_name = (params[:tree] || x_active_tree).to_sym
    tree_type = tree_name.to_s.sub(/_tree$/, '').to_sym
    tree_klass = x_tree(tree_name)[:klass_name]

    # FIXME after euwe: build_ae_tree
    tree_type = :catalog if controller_name == 'catalog' && tree_type == :automate

    nodes = TreeBuilder.tree_add_child_nodes(:sandbox    => @sb,
                                             :klass_name => tree_klass,
                                             :name       => tree_name,
                                             :type       => tree_type,
                                             :id         => id)
    TreeBuilder.convert_bs_tree(nodes)
  end

  def tree_exists?(tree_name)
    @sb[:trees].try(:key?, tree_name.to_s)
  end

  private ############################

  def parse_nodetype_and_id(x_node)
    x_node.split('_').last.split('-')
  end
end
