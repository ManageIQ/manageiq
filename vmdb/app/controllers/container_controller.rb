class ContainerController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  CONTAINER_X_BUTTON_ALLOWED_ACTIONS = {
    'container_delete'      => :container_delete,
    'container_edit'        => :container_edit
  }

  def button
    custom_buttons if params[:pressed] == "custom_button"
    return if ["custom_button"].include?(params[:pressed])    # custom button screen, so return, let custom_buttons method handle everything
  end

  def whitelisted_action(action)
    raise ActionController::RoutingError.new('invalid button action') unless
      CONTAINER_X_BUTTON_ALLOWED_ACTIONS.key?(action)

    send_action = CONTAINER_X_BUTTON_ALLOWED_ACTIONS[action]
    self.send(send_action)
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
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  # Container show selected, redirect to proper controller
  def show
    record = Container.find_by_id(from_cid(params[:id]))
    if !@explorer
      tree_node_id = TreeBuilder.build_node_id(record)
      redirect_to :controller => "container",
                  :action     => "explorer",
                  :id         => tree_node_id
      return
    end
    redirect_to :action => 'show', :controller=>record.class.base_model.to_s.underscore, :id=>record.id
  end

  def explorer
    @explorer   = true
    @lastaction = "explorer"

    # if AJAX request, replace right cell, and return
    if request.xml_http_request?
      replace_right_cell
      return
    end

    if params[:id]  # If a tree node id came in, show in one of the trees
      nodetype, id = params[:id].split("-")
      self.x_node = "#{nodetype}-#{to_cid(id)}"
    end

    # Build the Explorer screen from scratch
    @built_trees   = []
    @accords = []
    if role_allows(:feature => "container_accord", :any => true)
      self.x_active_tree   ||= 'containers_tree'
      self.x_active_accord ||= 'containers'
      @built_trees.push(build_containers_tree)
      @accords.push(:name      => "containers",
                    :title     => "Relationships",
                    :container => "containers_tree_div")
    end

    if role_allows(:feature => "container_filter_accord", :any => true)
      self.x_active_tree   ||= 'containers_filter_tree'
      self.x_active_accord ||= 'containers_filter'
      @built_trees.push(build_containers_filter_tree)
      @accords.push(:name      => "containers_filter",
                    :title     => "All Containers",
                    :container => "containers_filter_tree_div")
    end

    params.merge!(session[:exp_parms]) if session[:exp_parms]  # Grab any explorer parm overrides
    session.delete(:exp_parms)

    get_node_info(x_node)
    @in_a_form = false

    render :layout => "explorer"
  end

  def identify_container(id = nil)
    @container = @record = identify_record(id || params[:id])
  end

  # ST clicked on in the explorer right cell
  def x_show
    identify_container(from_cid(params[:id]))
    respond_to do |format|
      format.js do                  # AJAX, select the node
        @explorer = true
        params[:id] = x_build_node_id(@record,nil,x_tree(:containers_tree))  # Get the tree node id
        tree_select
      end
      format.html do                # HTML, redirect to explorer
        tree_node_id = TreeBuilder.build_node_id(@record)
        session[:exp_parms] = {:id => tree_node_id}
        redirect_to :action => "explorer"
      end
      format.any {render :nothing => true, :status => 404}
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
      listnav_search_selected(search_id) unless params.has_key?(:search_text) # Clear or set the adv search filter
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

  def get_record_display_name(record)
    record.name
  end

  # Get all info for the node about to be displayed
  def get_node_info(treenodeid)
    @show_adv_search = true
    @nodetype, id = valid_active_node(treenodeid).split("_").last.split("-")
    #resetting action that was stored during edit to determine what is being edited
    @sb[:action] = nil
    if x_node == "root" || TreeBuilder.get_model_for_prefix(@nodetype) == "MiqSearch"
      typ = "Container"
      process_show_list
      @right_cell_text = _("All %s") % ui_lookup(:models => typ)
    else
      show_record(from_cid(id))
      @right_cell_text = _("%{model} \"%{name}\"") % {:name => @record.name,
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

  #set partial name and cell header for edit screens
  def set_right_cell_vars(action)
    name = @record ? @record.name.to_s.gsub(/'/,"\\\\'") : "" # If record, get escaped name
    case action
    when "container_edit"
      partial = "container_form"
      header = _("Editing %{model} \"%{name}\"") % {:name => @record.name,
                                                    :model => ui_lookup(:model => "Container")}
      action = "container_edit"
    else
      action = nil
    end
    return partial,action,header
  end

  # Replace the right cell of the explorer
  def replace_right_cell(action = nil, replace_trees = [])
    @explorer = true
    partial, action_url, @right_cell_text = set_right_cell_vars(action) if action # Set partial name, action and cell header
    get_node_info(x_node) if !@in_a_form && !params[:display]
    replace_trees = @replace_trees if @replace_trees  # get_node_info might set this
    type, _ = x_node.split("_").last.split("-")
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

    render :update do |page|
      # Build hash of trees to replace and optional new node to be selected
      trees.each do |tree_name, tree|
        page.replace(
          "#{tree_name}_tree_div",
          :partial => 'shared/tree',
          :locals  => {
            :tree => tree,
            :name => tree.name
          }
        )
      end
      page << "dhxLayoutB.cells('b').setText('#{escape_javascript(h(@right_cell_text))}');"

      # Replace right cell divs
      if ["container_edit"].include?(action)
        page.replace_html("main_div", :partial=>partial)
      elsif params[:display]
        partial_locals = Hash.new
        partial_locals[:controller] = "container"
        partial = "layouts/x_gtl"
        if partial == "layouts/x_gtl"
          partial_locals[:action_url] = @lastaction
          page << "miq_parent_id = '#{@record.id}';"  # Set parent rec id for JS function miqGridSort to build URL
          page << "miq_parent_class = '#{request[:controller]}';" # Set parent class for URL also
        end
        page.replace_html("main_div", :partial => partial, :locals => partial_locals)

      elsif record_showing
        page.replace_html("main_div", :partial => "container/container_show", :locals => {:controller => "container"})
      else
        page.replace_html("main_div",   :partial => "layouts/x_gtl")
        page.replace_html("paging_div", :partial => "layouts/x_pagingcontrols")
      end

      page.replace("adv_searchbox_div",
                   :partial => "layouts/x_adv_searchbox")
      # Hide/show searchbox depending on if a list is showing
      page << set_element_visible("adv_searchbox_div", !(@record || @in_a_form))

#     # Decide whether to show paging controls
      if ["container_edit"].include?(action)
        page << "dhxLayoutB.cells('a').collapse();"
        page << "dhxLayoutB.cells('c').expand();" #incase it was collapsed for summary screen, and incase there were no records on show_list
        page << javascript_show("form_buttons_div")
        page << javascript_hide_if_exists("pc_div_1")
        locals = {:record_id => @edit[:rec_id], :action_url => action_url}
        page.replace_html("form_buttons_div", :partial => "layouts/x_edit_buttons", :locals => locals)
      elsif record_showing ||
        (@pages && (@items_per_page == ONE_MILLION || @pages[:items] == 0))
        #Added so buttons can be turned off even tho div is not being displayed it still pops up Abandon changes box when trying to change a node on tree after saving a record
        page << javascript_hide_if_exists("buttons_on")
        page << "dhxLayoutB.cells('a').expand();"
        page << "dhxLayoutB.cells('c').collapse();"
      else
        page << javascript_hide_if_exists("form_buttons_div")
        page << javascript_show("pc_div_1")
        page << "dhxLayoutB.cells('a').expand();"
        page << "dhxLayoutB.cells('c').expand();"
      end

      page << "$('#main_div').scrollTop();"  # Scroll to top of main div

      # Clear the JS gtl_list_grid var if changing to a type other than list
      if @gtl_type && @gtl_type != "list"
        page << "if (typeof gtl_list_grid != 'undefined') gtl_list_grid = undefined;"
      end

      # Rebuild the toolbars
      if h_buttons && h_xml
        page << javascript_for_toolbar_reload('history_tb', h_buttons, h_xml)
        page << javascript_show_if_exists("history_buttons_div")
      else
        page << javascript_hide_if_exists("history_buttons_div")
      end

      if v_buttons && v_xml
        page << javascript_for_toolbar_reload('view_tb', v_buttons, v_xml)
        page << javascript_show_if_exists("view_buttons_div")
      else
        page << javascript_hide_if_exists("view_buttons_div")
      end

      if c_buttons && c_xml
        page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
        page << javascript_show_if_exists("center_buttons_div")
      else
        page << javascript_hide_if_exists("center_buttons_div")
      end

      if h_buttons || c_buttons || v_buttons
        page << "dhxLayoutB.cells('a').expand();"
      else
        page << "dhxLayoutB.cells('a').collapse();"
      end

      if @record
        page << "miq_record_id = '#{@record.id}';"  # Create miq_record_id JS var, if @record is present
      else
        page << "miq_record_id = undefined;"  # reset this, otherwise it remembers previously selected id and sends up from list view when add button is pressed
      end

      page << "cfmeDynatree_activateNodeSilently('#{x_active_tree}','#{x_node}');" if params[:id]
      page << "$('##{x_active_tree}box').dynatree('#{@in_a_form && @edit ? 'disable' : 'enable'}');"
      dim_div = @in_a_form && @edit && @edit[:current] ? true : false
      page << javascript_dim("#{x_active_tree}_div", dim_div)
      page << "miqSparkle(false);"
    end
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
    @showtype = "config"
    identify_container(id)
    return if record_no_longer_exists?(@record)
  end

  def get_session_data
    @title      = "Containers"
    @layout     = "containers"
    @lastaction = session[:container_lastaction]
  end

  def set_session_data
    session[:container_lastaction] = @lastaction
  end
end
