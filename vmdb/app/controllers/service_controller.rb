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
      add_flash(I18n.t("flash.button.not_implemented") + " #{model}:#{action}", :error) unless @flash_array
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  # Service show selected, redirect to proper controller
  def show
    record = Service.find_by_id(from_cid(params[:id]))
    if !@explorer
      prefix = X_TREE_NODE_PREFIXES.invert[record.class.base_model.to_s]
      tree_node_id = "#{prefix}-#{record.id}" # Build the tree node id
      redirect_to :controller=>"service",
                  :action=>"explorer",
                  :id=>tree_node_id
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
        prefix = X_TREE_NODE_PREFIXES.invert[@record.class.base_model.to_s]
        tree_node_id = "#{prefix}-#{@record.id}"  # Build the tree node id
        session[:exp_parms] = {:id=>tree_node_id}
        redirect_to :action=>"explorer"
      end
      format.any {render :nothing=>true, :status=>404}  # Anything else, just send 404
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
          add_flash(I18n.t("flash.edit.cancelled",
                           :model=>"Service",:name=>session[:edit][:new][:description]))
        else
          add_flash(I18n.t("flash.add.cancelled",
                           :model=>"Service"))
        end
        @edit = nil
        @in_a_form = false
        replace_right_cell
      when "save","add"
        return unless load_edit("service_edit__#{params[:id] || "new"}","replace_cell__explorer")
        if @edit[:new][:name].blank?
          add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error)
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
          add_flash(I18n.t("flash.error_during", :task=>"Service Edit") << bang.message, :error)
        else
          add_flash(I18n.t("flash.edit.saved",
                           :model=>"Service",
                           :name=>@edit[:new][:name]))
        end
        @changed = session[:changed] = false
        @in_a_form = false
        @edit = session[:edit] = nil
        replace_right_cell(nil, [:svcs])
      when "reset", nil # Reset or first time in
        service_set_form_vars
        if params[:button] == "reset"
          add_flash(I18n.t("flash.edit.reset"), :warning)
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
      @right_cell_text = I18n.t("cell_header.task_model_record",
                                :task  => "Reconfigure",
                                :name  => st.name,
                                :model => ui_lookup(:model => "Service"))
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
        add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:tables=>"service"), :task=>"deletion"), :error)
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
    case X_TREE_NODE_PREFIXES[@nodetype]
    when "Service"  # VM or Template record, show the record
      show_record(from_cid(id))
      @right_cell_text = I18n.t("cell_header.model_record",
                                :name=>@record.name,
                                :model=>ui_lookup(:model=>X_TREE_NODE_PREFIXES[@nodetype]))
      @no_checkboxes = true
      @gtl_type = "grid"
      @items_per_page = ONE_MILLION
      @view, @pages = get_view(Vm, :parent=>@record, :parent_method => :all_vms, :all_pages=>true)  # Get the records (into a view) and the paginator
    else      # Get list of child Catalog Items/Services of this node
      if x_node == "root"
        typ = x_active_tree == :svcs_tree ? "Service" : "ServiceTemplate"
        process_show_list(:where_clause=>"service_id is null")
        @right_cell_text = I18n.t("cell_header.all_model_records",
                                  :model=>ui_lookup(:models=>typ))
        sync_view_pictures_to_disk(@view) if ["grid", "tile"].include?(@gtl_type)
      else
        show_record(from_cid(id))
        add_pictures_to_sync(@record.picture.id) if @record.picture
        typ = x_active_tree == :svcs_tree ? "Service" : X_TREE_NODE_PREFIXES[@nodetype]
        @right_cell_text = I18n.t("cell_header.model_record",
                                :name=>@record.name,
                                :model=>ui_lookup(:model=>typ))
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
        header = I18n.t("cell_header.set_ownership", :model=>ui_lookup(:model=>"Service"))
        action = "ownership_update"
      when "retire"
        partial = "shared/views/retire"
        header = I18n.t("cell_header.retire", :model=>ui_lookup(:model=>"Service"))
        action = "retire"
      when "service_edit"
        partial = "service_form"
        header = I18n.t("cell_header.editing_model_record",
                          :name=>@record.name,
                          :model=>ui_lookup(:model=>"Service"))
        action = "service_edit"
      when "tag"
        partial = "layouts/tagging"
        header = I18n.t("cell_header.edit_tags", :model=>ui_lookup(:model=>"Service"))
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
    record_showing = type && ["Service"].include?(X_TREE_NODE_PREFIXES[type])
    if x_active_tree == :svcs_tree && !@in_a_form && !@sb[:action]
      if record_showing && @sb[:action].nil?
        cb_buttons, cb_xml = build_toolbar_buttons_and_xml("custom_buttons_tb")
      else
        v_buttons, v_xml = build_toolbar_buttons_and_xml("x_gtl_view_tb")
      end
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
      if ["dialog_provision","ownership","retire","service_edit","tag"].include?(action)
        page.replace_html("main_div", :partial=>partial)
      elsif params[:display]
        partial_locals = Hash.new
        partial_locals[:controller] = "vm"
        partial = "layouts/x_gtl"
        if partial == "layouts/x_gtl"
          partial_locals[:action_url] = @lastaction
          page << "miq_parent_id = '#{@record.id}';"  # Set parent rec id for JS function miqGridSort to build URL
          page << "miq_parent_class = '#{request[:controller]}';" # Set parent class for URL also
        end
        page.replace_html("main_div", :partial=>partial, :locals=>partial_locals)

      elsif record_showing
        page.replace_html("main_div", :partial=>"service/svcs_show", :locals=>{:controller=>"service"})
      else
        page.replace_html("main_div", :partial=>"layouts/x_gtl")
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
      end

#     # Decide whether to show paging controls
      if ["dialog_provision","ownership","retire","service_edit", "tag"].include?(action)
        page << "dhxLayoutB.cells('a').collapse();"
        page << "dhxLayoutB.cells('c').expand();" #incase it was collapsed for summary screen, and incase there were no records on show_list
        page << "$('form_buttons_div').show();"
        page << "if($('pc_div_1')) $('pc_div_1').hide()";
        if action == "dialog_provision"
          page.replace_html("form_buttons_div", :partial => "layouts/x_dialog_buttons", :locals => {:action_url =>action_url, :record_id => @edit[:rec_id]})
        else
          if action == "retire"
            locals = {:action_url => action, :record_id => @record ? @record.id : nil}
            locals[:no_reset] = true
            locals[:multi_record] = true    # need save/cancel buttons on edit screen even tho @record.id is not there
            page << "miqBuildCalendar();"
          elsif action == "tag"
            locals = {:action_url => action_url}
            locals[:multi_record] = true    # need save/cancel buttons on edit screen even tho @record.id is not there
            locals[:record_id] = @sb[:rec_id] || @edit[:object_ids] && @edit[:object_ids][0]
          else
            locals = {:record_id => @edit[:rec_id], :action_url => action_url}
            if action == "ownership"
              locals[:multi_record] = true    # need save/cancel buttons on edit screen even tho @record.id is not there
            end
          end
          page.replace_html("form_buttons_div", :partial => "layouts/x_edit_buttons", :locals => locals)
        end
      elsif record_showing ||
          (@pages && (@items_per_page == ONE_MILLION || @pages[:items] == 0))
        #Added so buttons can be turned off even tho div is not being displayed it still pops up Abandon changes box when trying to change a node on tree after saving a record
        page << "if($('buttons_on')) $('buttons_on').hide();"
        page << "dhxLayoutB.cells('a').expand();"
        page << "dhxLayoutB.cells('c').collapse();"
      else
        page << "if ($('form_buttons_div')) $('form_buttons_div').hide();"
        page << "$('pc_div_1').show()"
        page << "dhxLayoutB.cells('a').expand();"
        page << "dhxLayoutB.cells('c').expand();"
      end

      page << "$('main_div').scrollTop = 0;"  # Scroll to top of main div

      # Clear the JS gtl_list_grid var if changing to a type other than list
      if @gtl_type && @gtl_type != "list"
        page << "if (typeof gtl_list_grid != 'undefined') gtl_list_grid = undefined;"
      end

      # Rebuild the toolbars
      if cb_buttons && cb_xml
        page << javascript_for_toolbar_reload('custom_tb', cb_buttons, cb_xml)
        page << "if($('custom_buttons_div')) $('custom_buttons_div').show();"
      else
        page << "if($('custom_buttons_div')) $('custom_buttons_div').hide();"
      end

      # Rebuild the toolbars
      if h_buttons && h_xml
        page << javascript_for_toolbar_reload('history_tb', h_buttons, h_xml)
        page << "if($('history_buttons_div')) $('history_buttons_div').show();"
      else
        page << "if($('history_buttons_div')) $('history_buttons_div').hide();"
      end

      if v_buttons && v_xml
        page << javascript_for_toolbar_reload('view_tb', v_buttons, v_xml)
        page << "if($('view_buttons_div')) $('view_buttons_div').show();"
      else
        page << "if($('view_buttons_div')) $('view_buttons_div').hide();"
      end

      if c_buttons && c_xml
        page << javascript_for_toolbar_reload('center_tb', c_buttons, c_xml)
        page << "if($('center_buttons_div')) $('center_buttons_div').show();"
      else
        page << "if($('center_buttons_div')) $('center_buttons_div').hide();"
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

      page << "cfmeDynatree_activateNodeSilently('#{x_active_tree.to_s}','#{x_node}');" if params[:id]
      page << "$j('##{x_active_tree}box').dynatree('#{@in_a_form && @edit ? 'disable' : 'enable'}');"
      dim_div = @in_a_form && @edit && @edit[:current] ? true : false
      page << "miqDimDiv('#{x_active_tree}_div',#{dim_div});"
      page << "miqSparkle(false);"
    end
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
