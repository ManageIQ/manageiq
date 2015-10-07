class ContainerController < ApplicationController
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  CONTAINER_X_BUTTON_ALLOWED_ACTIONS = {
    'container_delete' => :container_delete,
    'container_edit'   => :container_edit
  }

  def button
    custom_buttons if params[:pressed] == "custom_button"
    # custom button screen, so return, let custom_buttons method handle everything
    return if ["custom_button"].include?(params[:pressed])
  end

  def whitelisted_action(action)
    raise ActionController::RoutingError.new('invalid button action') unless
      CONTAINER_X_BUTTON_ALLOWED_ACTIONS.key?(action)

    send_action = CONTAINER_X_BUTTON_ALLOWED_ACTIONS[action]
    send(send_action)
    send_action
  end
  hide_action :whitelisted_action

  def x_button
    @explorer = true
    model, action = pressed2model_action(params[:pressed])
    @sb[:action] = action

    performed_action = whitelisted_action(params[:pressed])
    return if [:container_delete, :container_edit].include?(performed_action)

    if @refresh_partial
      replace_right_cell(action)
    else
      add_flash(_("Button not yet implemented") + " #{model}:#{action}", :error) unless @flash_array
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    end
  end

  # Container show selected, redirect to proper controller
  def show
    record = Container.find_by_id(from_cid(params[:id]))
    unless @explorer
      tree_node_id = TreeBuilder.build_node_id(record)
      redirect_to :controller => "container",
                  :action     => "explorer",
                  :id         => tree_node_id
      return
    end
    redirect_to :action => 'show', :controller => record.class.base_model.to_s.underscore, :id => record.id
  end

  def explorer
    @explorer   = true
    @lastaction = "explorer"

    # if AJAX request, replace right cell, and return
    if request.xml_http_request?
      replace_right_cell
      return
    end

    # Build the Explorer screen from scratch
    @built_trees   = []
    @accords = []
    if role_allows(:feature => "container_accord", :any => true)
      self.x_active_tree ||= 'containers_tree'
      self.x_active_accord ||= 'containers'
      @built_trees.push(build_containers_tree)
      @accords.push(:name      => "containers",
                    :title     => "Relationships",
                    :container => "containers_tree_div")
    end

    if role_allows(:feature => "container_filter_accord", :any => true)
      self.x_active_tree ||= 'containers_filter_tree'
      self.x_active_accord ||= 'containers_filter'
      @built_trees.push(build_containers_filter_tree)
      @accords.push(:name      => "containers_filter",
                    :title     => "All Containers",
                    :container => "containers_filter_tree_div")
    end

    if params[:id]  # If a tree node id came in, show in one of the trees
      nodetype, id = params[:id].split("-")
      # treebuilder initializes x_node to root first time in locals_for_render,
      # need to set this here to force & activate node when link is clicked outside of explorer.
      @reselect_node = self.x_node = "#{nodetype}-#{to_cid(id)}"
    end

    params.merge!(session[:exp_parms]) if session[:exp_parms]  # Grab any explorer parm overrides
    session.delete(:exp_parms)

    get_node_info(x_node)
    @in_a_form = false

    render :layout => "application"
  end

  def identify_container(id = nil)
    @container = @record = identify_record(id || params[:id])
  end

  # ST clicked on in the explorer right cell
  def x_show
    get_tagdata(Container.find_by_id(from_cid(params[:id])))
    identify_container(from_cid(params[:id]))
    respond_to do |format|
      format.js do                  # AJAX, select the node
        @explorer = true
        params[:id] = x_build_node_id(@record, nil, x_tree(:containers_tree))  # Get the tree node id
        tree_select
      end
      format.html do                # HTML, redirect to explorer
        tree_node_id = TreeBuilder.build_node_id(@record)
        session[:exp_parms] = {:id => tree_node_id}
        redirect_to :action => "explorer"
      end
      format.any { render :nothing => true, :status => 404 }
    end
  end

  # Tree node selected in explorer
  def tree_select
    @explorer = true
    @lastaction = "explorer"
    self.x_node = params[:id]
    @nodetype, id = params[:id].split("_").last.split("-")

    if x_tree[:type] == :containers_filter && TreeBuilder.get_model_for_prefix(@nodetype) != "Container"
      search_id = @nodetype == "root" ? 0 : from_cid(id)
      adv_search_build(vm_model_from_active_tree(x_active_tree))
      session[:edit] = @edit              # Set because next method will restore @edit from session
      listnav_search_selected(search_id) unless params.key?(:search_text) # Clear or set the adv search filter
      if @edit[:adv_search_applied] &&
         MiqExpression.quick_search?(@edit[:adv_search_applied][:exp]) &&
         %w(reload tree_select).include?(params[:action])
        self.x_node = params[:id]
        quick_search_show
        return
      end
    end

    replace_right_cell
  end

  # Accordion selected in explorer
  def accordion_select
    @layout     = "explorer"
    @lastaction = "explorer"
    self.x_active_accord = params[:id]
    self.x_active_tree   = "#{params[:id]}_tree"
    replace_right_cell
  end

  private

  # Get all info for the node about to be displayed
  def get_node_info(treenodeid)
    @show_adv_search = true
    @nodetype, id = valid_active_node(treenodeid).split("_").last.split("-")
    # resetting action that was stored during edit to determine what is being edited
    @sb[:action] = nil
    if x_node == "root" || TreeBuilder.get_model_for_prefix(@nodetype) == "MiqSearch"
      typ = "Container"
      process_show_list
      @right_cell_text = _("All %s") % ui_lookup(:models => typ)
    else
      show_record(from_cid(id))
      @right_cell_text = _("%{model} \"%{name}\"") % {:name  => @record.name,
                                                      :model => ui_lookup(:model => TreeBuilder.get_model_for_prefix(@nodetype))}
    end

    if @edit && @edit.fetch_path(:adv_search_applied, :qs_exp) # If qs is active, save it in history
      x_history_add_item(:id     => x_node,
                         :qs_exp => @edit[:adv_search_applied][:qs_exp],
                         :text   => @right_cell_text)
    else
      x_history_add_item(:id => treenodeid, :text => @right_cell_text)  # Add to history pulldown array
    end

    # After adding to history, add name filter suffix if showing a list
    unless @search_text.blank?
      @right_cell_text += _(" (Names with \"%s\")") % @search_text
    end
  end

  # set partial name and cell header for edit screens
  def set_right_cell_vars(action)
    case action
    when "container_edit"
      partial = "container_form"
      header = _("Editing %{model} \"%{name}\"") % {:name  => @record.name,
                                                    :model => ui_lookup(:model => "Container")}
      action = "container_edit"
    else
      action = nil
    end
    return partial, action, header
  end

  # Replace the right cell of the explorer
  def replace_right_cell(action = nil, replace_trees = [])
    @explorer = true
    # Set partial name, action and cell header
    partial, action_url, @right_cell_text = set_right_cell_vars(action) if action
    get_node_info(x_node) if !@in_a_form && !params[:display]
    replace_trees = @replace_trees if @replace_trees  # get_node_info might set this
    type, = x_node.split("_").last.split("-")
    trees = {}
    if replace_trees
      trees[:containers] = build_containers_tree if replace_trees.include?(:containers)
    end
    record_showing = type && ["Container"].include?(TreeBuilder.get_model_for_prefix(type))
    if !@in_a_form && !@sb[:action]
      v_buttons, v_xml = build_toolbar_buttons_and_xml("x_gtl_view_tb") unless record_showing
      c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
    end
    h_buttons, h_xml = build_toolbar_buttons_and_xml("x_history_tb") unless @in_a_form

    # Build presenter to render the JS command for the tree update
    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
    )
    r = proc { |opts| render_to_string(opts) }

    # Build hash of trees to replace and optional new node to be selected
    replace_trees.each do |t|
      tree = trees[t]
      presenter[:replace_partials]["#{t}_tree_div".to_sym] = r[
        :partial => 'shared/tree',
        :locals  => {:tree => tree,
                     :name => tree.name.to_s
        }
      ]
    end
    presenter[:right_cell_text] = @right_cell_text

    if action == "container_edit"
      presenter[:update_partials][:main_div] = r[:partial => partial]
    elsif params[:display]
      partial_locals = {:controller => "container", :action_url => @lastaction}
      partial = "layouts/x_gtl"
      presenter[:parent_id]    = @record.id           # Set parent rec id for JS function miqGridSort to build URL
      presenter[:parent_class] = request[:controller] # Set parent class for URL also
      presenter[:update_partials][:main_div] = r[:partial => partial, :locals => partial_locals]
    elsif record_showing
      presenter[:update_partials][:main_div] = r[:partial => "container/container_show", :locals => {:controller => "container"}]
      presenter[:set_visible_elements][:pc_div_1] = false
      presenter[:show_hide_layout][:paginator] = 'hide'
    else
      presenter[:update_partials][:main_div] = r[:partial => "layouts/x_gtl"]
      presenter[:update_partials][:paging_div] = r[:partial => "layouts/x_pagingcontrols"]
      presenter[:set_visible_elements][:form_buttons_div] = false
      presenter[:set_visible_elements][:pc_div_1] = true
      presenter[:show_hide_layout][:paginator] = 'show'
    end

    presenter[:replace_partials][:adv_searchbox_div] = r[:partial => 'layouts/x_adv_searchbox']

    # Clear the JS ManageIQ.grids.grids['gtl_list_grid'].obj var if changing to a type other than list
    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'

    # Rebuild the toolbars
    presenter[:set_visible_elements][:history_buttons_div] = h_buttons && h_xml
    presenter[:set_visible_elements][:center_buttons_div]  = c_buttons && c_xml
    presenter[:set_visible_elements][:view_buttons_div]    = v_buttons && v_xml

    presenter[:reload_toolbars][:history] = {:buttons => h_buttons,  :xml => h_xml}  if h_buttons && h_xml
    presenter[:reload_toolbars][:center]  = {:buttons => c_buttons,  :xml => c_xml}  if c_buttons && c_xml
    presenter[:reload_toolbars][:view]    = {:buttons => v_buttons,  :xml => v_xml}  if v_buttons && v_xml

    presenter[:show_hide_layout][:toolbar] = h_buttons || c_buttons || v_buttons ? 'show' : 'hide'

    presenter[:record_id] = @record ? @record.id : nil

    # Hide/show searchbox depending on if a list is showing
    presenter[:set_visible_elements][:adv_searchbox_div] = !(@record || @in_a_form)
    presenter[:clear_search_show_or_hide] = clear_search_show_or_hide

    presenter[:osf_node] = x_node  # Open, select, and focus on this node

    presenter[:set_visible_elements][:blocker_div]    = false unless @edit && @edit[:adv_search_open]
    presenter[:set_visible_elements][:quicksearchbox] = false
    presenter[:lock_unlock_trees][x_active_tree] = @in_a_form && @edit
    # Render the JS responses to update the explorer screen
    render :js => presenter.to_html
  end

  # Build a Containers explorer tree
  def build_containers_tree
    TreeBuilderContainers.new("containers_tree", "containers", @sb)
  end

  def build_containers_filter_tree
    TreeBuilderContainersFilter.new("containers_filter_tree", "containers_filter", @sb)
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    x_get_child_nodes_dynatree(x_active_tree, id)
  end

  def show_record(id = nil)
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype = "main"
    identify_container(id)
    return if record_no_longer_exists?(@record)
  end
end
