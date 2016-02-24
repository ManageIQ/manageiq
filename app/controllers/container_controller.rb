class ContainerController < ApplicationController
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  CONTAINER_X_BUTTON_ALLOWED_ACTIONS = {
    'container_delete'   => :container_delete,
    'container_edit'     => :container_edit,
    'container_tag'      => :container_tag,
    'container_timeline' => :show_timeline,
    'container_perf'     => :show
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
    if [:container_tag].include?(send_action)
      send(send_action, 'Container')
    else
      send(send_action)
    end
    send_action
  end
  private :whitelisted_action

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
    return if perfmenu_click?
    @sb[:action] = params[:display]
    @display = params[:display] || "main" unless control_selected?

    identify_container(params[:id])
    if @display == "performance"
      @showtype = "performance"
      perf_gen_init_options
      @refresh_partial = "layouts/performance"
    end

    node_type = TreeBuilder.get_prefix_for_model(@record.class.base_model)
    redirect_to :action     => 'explorer',
                :controller => @record.class.base_model.to_s.underscore,
                :id         => "#{node_type}-#{@record.id}" unless @display == "performance"
  end

  def show_timeline
    @showtype = "timeline"
    session[:tl_record_id] = params[:id]
    @record = Container.find_by_id(from_cid(params[:id]))
    @timeline = @timeline_filter = true
    @lastaction = "show_timeline"
    tl_build_timeline                       # Create the timeline report
    @refresh_partial = "layouts/tl_show"
    if params[:refresh]
      @sb[:action] = "timeline"
      replace_right_cell
    end
  end

  def show_list
    redirect_to :controller => "container",
                :action     => "explorer"
  end

  def explorer
    @explorer   = true
    @lastaction = "explorer"
    @timeline = @timeline_filter = true    # need to set these to load timelines on container show screen

    # if AJAX request, replace right cell, and return
    if request.xml_http_request?
      replace_right_cell
      return
    end

    build_accordions_and_trees

    if params[:id]  # If a tree node id came in, show in one of the trees
      nodetype, id = params[:id].split("-")
      # treebuilder initializes x_node to root first time in locals_for_render,
      # need to set this here to force & activate node when link is clicked outside of explorer.
      @reselect_node = self.x_node = "#{nodetype}-#{to_cid(id)}"
    end

    params.instance_variable_get(:@parameters).merge!(session[:exp_parms]) if session[:exp_parms]  # Grab any explorer parm overrides
    session.delete(:exp_parms)
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
        params[:id] = x_build_node_id(@record, x_tree(:containers_tree))  # Get the tree node id
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
    self.x_active_accord = params[:id].sub(/_accord$/, '')
    self.x_active_tree   = "#{self.x_active_accord}_tree"
    replace_right_cell
  end

  private

  def features
    [{:role     => "container_accord",
      :role_any => true,
      :name     => :containers,
      :title    => N_("Relationships")},

     {:role     => "container_filter_accord",
      :role_any => true,
      :name     => :containers_filter,
      :title    => N_("All Containers")},
    ].map do |hsh|
      ApplicationController::Feature.new_with_hash(hsh)
    end
  end


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
    when "tag"
      partial = "layouts/tagging"
      header = _("Edit Tags for %s") % ui_lookup(:model => "Container")
      action = "container_tag"
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
      v_tb = build_toolbar("x_gtl_view_tb") unless record_showing
      c_tb = build_toolbar(center_toolbar_filename)
    end
    h_tb = build_toolbar("x_history_tb") unless @in_a_form

    # Build presenter to render the JS command for the tree update
    presenter = ExplorerPresenter.new(
      :active_tree     => x_active_tree,
      :right_cell_text => @right_cell_text
    )
    r = proc { |opts| render_to_string(opts) }

    replace_trees_by_presenter(presenter, trees)

    if action == "container_edit" || action == "tag"
      presenter.update(:main_div, r[:partial => partial])
    elsif params[:display]
      partial_locals = {:controller => "container", :action_url => @lastaction}
      if params[:display] == "timeline"
        partial = "layouts/tl_show"
      elsif params[:display] == "performance"
        partial = "layouts/performance"
      else
        partial = "layouts/x_gtl"
      end
      presenter[:parent_id]    = @record.id           # Set parent rec id for JS function miqGridSort to build URL
      presenter[:parent_class] = params[:controller] # Set parent class for URL also
      presenter.update(:main_div, r[:partial => partial, :locals => partial_locals])
    elsif record_showing
      presenter.update(:main_div, r[:partial => "container/container_show", :locals => {:controller => "container"}])
      presenter.hide(:pc_div_1, :paging_div)
    else
      presenter.update(:main_div, r[:partial => "layouts/x_gtl"])
      presenter.update(:paging_div, r[:partial => "layouts/x_pagingcontrols"])
      presenter.hide(:form_buttons_div).show(:pc_div_1, :paging_div)
    end

    if %w(tag).include?(action)
      presenter.show(:form_buttons_div).hide(:pc_div_1, :toolbar).show(:paging_div)
      locals = {:action_url => action_url}
      locals[:multi_record] = true # need save/cancel buttons on edit screen even tho @record.id is not there
      locals[:record_id]    = @sb[:rec_id] || @edit[:object_ids] && @edit[:object_ids][0]
      presenter.update(:form_buttons_div, r[:partial => "layouts/x_edit_buttons", :locals => locals])
    end

    presenter[:ajax_action] = {
      :controller => request.parameters["controller"],
      :action     => @ajax_action,
      :record_id  => @record.id
    } if ['performance', 'timeline'].include?(@sb[:action])

    presenter.replace(:adv_searchbox_div, r[:partial => 'layouts/x_adv_searchbox'])

    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'

    presenter.reload_toolbars(:history => h_tb, :center => c_tb, :view => v_tb)

    presenter.set_visibility(h_tb.present? || c_tb.present? || v_tb.present?, :toolbar)

    presenter[:record_id] = @record ? @record.id : nil

    # Hide/show searchbox depending on if a list is showing
    presenter.set_visibility(!(@record || @in_a_form), :adv_searchbox_div)
    presenter[:clear_search_show_or_hide] = clear_search_show_or_hide

    presenter[:osf_node] = x_node  # Open, select, and focus on this node

    presenter.hide(:blocker_div) unless @edit && @edit[:adv_search_open]
    presenter.hide(:quicksearchbox)
    presenter[:lock_unlock_trees][x_active_tree] = @in_a_form && @edit
    # Render the JS responses to update the explorer screen
    render :js => presenter.to_html
  end

  # Build a Containers explorer tree
  def build_containers_tree
    TreeBuilderContainers.new("containers_tree", "containers", @sb)
  end

  def show_record(id = nil)
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype = "main"
    identify_container(id)
    return if record_no_longer_exists?(@record)
  end

  def tagging_explorer_controller?
    @explorer
  end
end
