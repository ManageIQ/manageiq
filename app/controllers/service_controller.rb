class ServiceController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  SERVICE_X_BUTTON_ALLOWED_ACTIONS = {
    'service_delete'      => :service_delete,
    'service_edit'        => :service_edit,
    'service_ownership'   => :service_ownership,
    'service_tag'         => :service_tag,
    'service_retire'      => :service_retire,
    'service_retire_now'  => :service_retire_now,
    'service_reconfigure' => :service_reconfigure
  }

  def button
    custom_buttons if params[:pressed] == "custom_button"
    return if ["custom_button"].include?(params[:pressed])    # custom button screen, so return, let custom_buttons method handle everything
  end

  def whitelisted_action(action)
    raise ActionController::RoutingError.new('invalid button action') unless
      SERVICE_X_BUTTON_ALLOWED_ACTIONS.key?(action)

    send_action = SERVICE_X_BUTTON_ALLOWED_ACTIONS[action]

    if [:service_ownership, :service_tag].include?(send_action)
      self.send(send_action, 'Service')
    else
      self.send(send_action)
    end
    send_action
  end
  hide_action :whitelisted_action

  def x_button
    @explorer = true
    model, action = pressed2model_action(params[:pressed])
    @sb[:action] = action

    performed_action = whitelisted_action(params[:pressed])
    return if [:service_delete, :service_edit, :service_reconfigure].include?(performed_action)

    if @refresh_partial
      replace_right_cell(action)
    else
      add_flash(_("Button not yet implemented") + " #{model}:#{action}", :error) unless @flash_array
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  # Service show selected, redirect to proper controller
  def show
    record = Service.find_by_id(from_cid(params[:id]))
    if !@explorer
      tree_node_id = TreeBuilder.build_node_id(record)
      redirect_to :controller => "service",
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
    if role_allows(:feature => "service", :any => true)
      self.x_active_tree   ||= 'svcs_tree'
      self.x_active_accord ||= 'svcs'
      @built_trees << build_svcs_tree
      @accords.push(:name      => "svcs",
                    :title     => "Services",
                    :container => "svcs_tree_div")
    end

    params.merge!(session[:exp_parms]) if session[:exp_parms]  # Grab any explorer parm overrides
    session.delete(:exp_parms)

    get_node_info(x_node)
    @in_a_form = false

    render :layout => "explorer"
  end

  def identify_service(id = nil)
    @st = @record = identify_record(id || params[:id])
  end

  # ST clicked on in the explorer right cell
  def x_show
    identify_service(from_cid(params[:id]))
    respond_to do |format|
      format.js do                  # AJAX, select the node
        @explorer = true
        params[:id] = x_build_node_id(@record,nil,x_tree(:svcs_tree))  # Get the tree node id
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

  def service_edit
    assert_privileges("service_edit")
    case params[:button]
      when "cancel"
        if session[:edit][:rec_id]
          add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>"Service", :name=>session[:edit][:new][:description]})
        else
          add_flash(_("Add of new %s was cancelled by the user") % "Service")
        end
        @edit = nil
        @in_a_form = false
        replace_right_cell
      when "save","add"
        return unless load_edit("service_edit__#{params[:id] || "new"}","replace_cell__explorer")
        if @edit[:new][:name].blank?
          add_flash(_("%s is required") % "Name", :error)
        end

        if @flash_array
          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
          return
        end
        @service = Service.find_by_id(@edit[:rec_id])
        service_set_record_vars(@service)
        begin
          @service.save
        rescue StandardError => bang
          add_flash(_("Error during '%s': ") % "Service Edit" << bang.message, :error)
        else
          add_flash(_("%{model} \"%{name}\" was saved") % {:model=>"Service", :name=>@edit[:new][:name]})
        end
        @changed = session[:changed] = false
        @in_a_form = false
        @edit = session[:edit] = nil
        replace_right_cell(nil, [:svcs])
      when "reset", nil # Reset or first time in
        service_set_form_vars
        if params[:button] == "reset"
          add_flash(_("All changes have been reset"), :warning)
        end
        @changed = session[:changed] = false
        replace_right_cell("service_edit")
        return
    end
  end

  def service_reconfigure
    s = Service.find_by_id(from_cid(params[:id]))
    st = s.service_template
    ra = st.resource_actions.find_by_action('Reconfigure') if st
    if ra && ra.dialog_id
      @right_cell_text = _("%{task} %{model} \"%{name}\"") % {:task  => "Reconfigure", :name  => st.name, :model => ui_lookup(:model => "Service")}
      @explorer = true
      options = {
        :header      => @right_cell_text,
        :target_id   => s.id,
        :target_kls  => s.class.name,
        :dialog      => s.options[:dialog],
        :dialog_mode => :reconfigure
      }
      dialog_initialize(ra, options)
    end
  end

  def service_form_field_changed
    id = session[:edit][:rec_id] || "new"
    return unless load_edit("service_edit__#{id}","replace_cell__explorer")
    service_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      if changed != session[:changed]
        page << javascript_for_miq_button_visibility(changed)
        session[:changed] = changed
      end
      page << "miqSparkle(false);"
    end
  end

  private

  def service_get_form_vars
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]
  end

  def service_set_form_vars
    checked = find_checked_items
    checked[0] = params[:id] if checked.blank? && params[:id]
    @record = find_by_id_filtered(Service, checked[0])
    @edit = Hash.new
    @edit[:key] = "service_edit__#{@record.id || "new"}"
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:rec_id] = @record.id
    @edit[:new][:name] = @record.name
    @edit[:new][:description] = @record.description
    @edit[:current] = copy_hash(@edit[:new])
    @in_a_form = true
  end

  def service_set_record_vars(svc)
    svc.name = @edit[:new][:name]
    svc.description = @edit[:new][:description]
  end

  def service_delete
    assert_privileges("service_delete")
    elements = Array.new
    if params[:id]
      elements.push(params[:id])
      process_elements(elements, Service, 'destroy') unless elements.empty?
      self.x_node = "root"
    else # showing 1 element, delete it
      elements = find_checked_items
      if elements.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>"service"), :task=>"deletion"}, :error)
      end
      process_elements(elements, Service, 'destroy') unless elements.empty?
    end
    params[:id] = nil
    replace_right_cell(nil, [:svcs])
  end

  def get_record_display_name(record)
    record.name
  end

  # Get all info for the node about to be displayed
  def get_node_info(treenodeid)
    @nodetype, id = valid_active_node(treenodeid).split("_").last.split("-")
    #resetting action that was stored during edit to determine what is being edited
    @sb[:action] = nil
    case TreeBuilder.get_model_for_prefix(@nodetype)
    when "Service"  # VM or Template record, show the record
      show_record(from_cid(id))
      @right_cell_text = _("%{model} \"%{name}\"") % {:name=>@record.name, :model=>ui_lookup(:model=>TreeBuilder.get_model_for_prefix(@nodetype))}
      @no_checkboxes = true
      @gtl_type = "grid"
      @items_per_page = ONE_MILLION
      @view, @pages = get_view(Vm, :parent=>@record, :parent_method => :all_vms, :all_pages=>true)  # Get the records (into a view) and the paginator
    else      # Get list of child Catalog Items/Services of this node
      if x_node == "root"
        typ = x_active_tree == :svcs_tree ? "Service" : "ServiceTemplate"
        process_show_list(:where_clause=>"service_id is null")
        @right_cell_text = _("All %s") % ui_lookup(:models=>typ)
        sync_view_pictures_to_disk(@view) if ["grid", "tile"].include?(@gtl_type)
      else
        show_record(from_cid(id))
        add_pictures_to_sync(@record.picture.id) if @record.picture
        typ = x_active_tree == :svcs_tree ? "Service" : TreeBuilder.get_model_for_prefix(@nodetype)
        @right_cell_text = _("%{model} \"%{name}\"") % {:name=>@record.name, :model=>ui_lookup(:model=>typ)}
      end
    end
    x_history_add_item(:id=>treenodeid, :text=>@right_cell_text)
  end

  #set partial name and cell header for edit screens
  def set_right_cell_vars(action)
    name = @record ? @record.name.to_s.gsub(/'/,"\\\\'") : "" # If record, get escaped name
    case action
      when "dialog_provision"
        partial = "shared/dialogs/dialog_provision"
        header = @right_cell_text
        action = "dialog_form_button_pressed"
      when "ownership"
        partial = "shared/views/ownership"
        header = _("Set Ownership for %s") % ui_lookup(:model=>"Service")
        action = "ownership_update"
      when "retire"
        partial = "shared/views/retire"
        header = _("Set/Remove retirement date for %s") % ui_lookup(:model=>"Service")
        action = "retire"
      when "service_edit"
        partial = "service_form"
        header = _("Editing %{model} \"%{name}\"") % {:name=>@record.name, :model=>ui_lookup(:model=>"Service")}
        action = "service_edit"
      when "tag"
        partial = "layouts/tagging"
        header = _("Edit Tags for %s") % ui_lookup(:model=>"Service")
        action = "service_tag"
      else
        action = nil
    end
    return partial,action,header
  end

  # Replace the right cell of the explorer
  def replace_right_cell(action = nil, replace_trees = [])
    @explorer = true
    partial, action_url, @right_cell_text = set_right_cell_vars(action) if action # Set partial name, action and cell header
    get_node_info(x_node) if !@edit && !@in_a_form && !params[:display]
    replace_trees = @replace_trees if @replace_trees  # get_node_info might set this
    type, _ = x_node.split("_").last.split("-")
    trees = {}
    if replace_trees
      trees[:svcs] = build_svcs_tree if replace_trees.include?(:svcs)
    end
    record_showing = type && ["Service"].include?(TreeBuilder.get_model_for_prefix(type))
    if x_active_tree == :svcs_tree && !@in_a_form && !@sb[:action]
      if record_showing && @sb[:action].nil?
        cb_buttons, cb_xml = build_toolbar_buttons_and_xml("custom_buttons_tb")
      else
        v_buttons, v_xml = build_toolbar_buttons_and_xml("x_gtl_view_tb")
      end
      c_buttons, c_xml = build_toolbar_buttons_and_xml(center_toolbar_filename)
    end
    h_buttons, h_xml = build_toolbar_buttons_and_xml("x_history_tb") unless @in_a_form

    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
    )
    r = proc { |opts| render_to_string(opts) }

    # Build hash of trees to replace and optional new node to be selected
    trees.each do |t|
      tree = trees[t]
      presenter[:replace_partials]["#{t}_tree_div".to_sym] = r[
          :partial => 'shared/tree',
          :locals  => {:tree => tree,
                       :name => tree.name.to_s
          }
      ]
    end

    presenter[:right_cell_text] = @right_cell_text

    # Replace right cell divs
    presenter[:update_partials][:main_div] =
      if ["dialog_provision","ownership","retire","service_edit","tag"].include?(action)
        r[:partial => partial]
      elsif params[:display]
        r[:partial => 'layouts/x_gtl', :locals => {:controller => "vm", :action_url => @lastaction}]
      elsif record_showing
        r[:partial => "service/svcs_show", :locals => {:controller => "service"}]
      else
        presenter[:update_partials][:paging_div] = r[:partial => "layouts/x_pagingcontrols"]
        r[:partial => "layouts/x_gtl"]
      end
    if %w(dialog_provision ownership service_edit tag).include?(action)
      presenter[:set_visible_elements][:form_buttons_div] = true
      presenter[:set_visible_elements][:pc_div_1] = false
      presenter[:show_hide_layout][:toolbar] = 'hide'
      presenter[:show_hide_layout][:paginator] = 'show'
      if action == "dialog_provision"
        presenter[:update_partials][:form_buttons_div] = r[:partial => "layouts/x_dialog_buttons",
                                                           :locals  => {:action_url => action_url,
                                                                        :record_id  => @edit[:rec_id]}]
      else
        if action == "tag"
          locals = {:action_url => action_url}
          locals[:multi_record] = true    # need save/cancel buttons on edit screen even tho @record.id is not there
          locals[:record_id]    = @sb[:rec_id] || @edit[:object_ids] && @edit[:object_ids][0]
        else
          locals = {:record_id => @edit[:rec_id], :action_url => action_url}
          # need save/cancel buttons on edit screen even tho @record.id is not there
          locals[:multi_record] = true if action == "ownership"
        end
        presenter[:update_partials][:form_buttons_div] = r[:partial => "layouts/x_edit_buttons", :locals => locals]
      end
    elsif (action != "retire") && (record_showing ||
        (@pages && (@items_per_page == ONE_MILLION || @pages[:items] == 0)))
      # Added so buttons can be turned off even tho div is not being displayed it still pops up Abandon changes box
      # when trying to change a node on tree after saving a record
      presenter[:set_visible_elements][:buttons_on] = false
      presenter[:show_hide_layout][:toolbar]        = 'show'
      presenter[:show_hide_layout][:paginator]      = 'hide'
    else
      presenter[:set_visible_elements][:form_buttons_div] = false
      presenter[:set_visible_elements][:pc_div_1]         = true
      presenter[:show_hide_layout][:toolbar]              = 'show'
      presenter[:show_hide_layout][:paginator]            = 'show'
    end

    # Clear the JS gtl_list_grid var if changing to a type other than list
    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'

    if @record.kind_of?(Dialog)
      @record.dialog_fields.each do |field|
        if %w(DialogFieldDateControl DialogFieldDateTimeControl).include?(field.type)
          presenter[:build_calendar]  = {
            :date_from => field.show_past_dates ? nil : Time.zone.now.to_i * 1000
          }
        end
      end
    end

    # Rebuild the toolbars
    presenter[:set_visible_elements][:history_buttons_div] = h_buttons  && h_xml
    presenter[:set_visible_elements][:center_buttons_div]  = c_buttons  && c_xml
    presenter[:set_visible_elements][:view_buttons_div]    = v_buttons  && v_xml
    presenter[:set_visible_elements][:custom_buttons_div]  = cb_buttons && cb_xml
    presenter[:reload_toolbars][:history] = {:buttons => h_buttons,  :xml => h_xml}  if h_buttons  && h_xml
    presenter[:reload_toolbars][:center]  = {:buttons => c_buttons,  :xml => c_xml}  if c_buttons  && c_xml
    presenter[:reload_toolbars][:view]    = {:buttons => v_buttons,  :xml => v_xml}  if v_buttons  && v_xml
    presenter[:reload_toolbars][:custom]  = {:buttons => cb_buttons, :xml => cb_xml} if cb_buttons && cb_xml

    presenter[:show_hide_layout][:toolbar] = h_buttons || c_buttons || v_buttons ? 'show' : 'hide'

    if @record && !@in_a_form
      presenter[:record_id] = @record.id
    else
      presenter[:record_id] = @edit && @edit[:rec_id] && @in_a_form ? @edit[:rec_id] : nil
    end

    presenter[:lock_unlock_trees][x_active_tree] = @edit && @edit[:current]
    presenter[:osf_node] = x_node
    # unset variable that was set in form_field_changed to prompt for changes when leaving the screen
    presenter[:extra_js] << "ManageIQ.changes = null;"

    # Render the JS responses to update the explorer screen
    render :js => presenter.to_html
  end

  # Build a Services explorer tree
  def build_svcs_tree
    TreeBuilderServices.new("svcs_tree", "svcs", @sb)
  end

  # Add the children of a node that is being expanded (autoloaded), called by generic tree_autoload method
  def tree_add_child_nodes(id)
    x_get_child_nodes_dynatree(x_active_tree, id)
  end

  def show_record(id = nil)
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype = "config"
    identify_service(id)
    return if record_no_longer_exists?(@record)

    get_tagdata(@record)
  end

  def tagging_explorer_controller?
    @explorer
  end

  def get_session_data
    @title      = "My Services"
    @layout     = "services"
    @lastaction = session[:svc_lastaction]
    @options    = session[:prov_options]
  end

  def set_session_data
    session[:svc_lastaction] = @lastaction
    session[:prov_options]   = @options if @options
  end
end
