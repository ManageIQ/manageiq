class CatalogController < ApplicationController
  include AutomateTreeHelper

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    @model ||= ServiceTemplate
  end

  def self.table_name
    @table_name ||= "service_template"
  end

  CATALOG_X_BUTTON_ALLOWED_ACTIONS = {
    'ab_button_new'                 => :ab_button_new,
    'ab_button_edit'                => :ab_button_edit,
    'ab_button_delete'              => :ab_button_delete,
    'ab_group_delete'               => :ab_group_delete,
    'ab_group_edit'                 => :ab_group_edit,
    'ab_group_new'                  => :ab_group_new,
    'ab_group_reorder'              => :ab_group_reorder,
    'svc_catalog_provision'         => :svc_catalog_provision,
    'st_catalog_delete'             => :st_catalog_delete,

    'atomic_catalogitem_edit'       => :servicetemplate_edit,
    'atomic_catalogitem_new'        => :servicetemplate_edit,
    'catalogitem_edit'              => :servicetemplate_edit,
    'catalogitem_new'               => :servicetemplate_edit,

    'catalogitem_delete'            => :st_delete,
    'catalogitem_tag'               => :st_tags_edit,

    'orchestration_template_add'    => :ot_add,
    'orchestration_template_edit'   => :ot_edit,
    'orchestration_template_copy'   => :ot_copy,
    'orchestration_template_remove' => :ot_remove_submit,
    'orchestration_template_tag'    => :ot_tags_edit,
    'service_dialog_from_ot'        => :service_dialog_from_ot,
    'st_catalog_edit'               => :st_catalog_edit,
    'st_catalog_new'                => :st_catalog_edit,
  }.freeze

  ORCHESTRATION_TEMPLATES_NODES = {
    'OrchestrationTemplateCfn'   => "otcfn",
    'OrchestrationTemplateHot'   => "othot",
    'OrchestrationTemplateAzure' => "otazu"
  }.freeze

  def x_button
    # setting this here so it can be used in the common code
    @sb[:action] = action = params[:pressed]
    @sb[:applies_to_class] = 'ServiceTemplate'

    # guard this 'router' by matching against a list of allowed actions
    unless CATALOG_X_BUTTON_ALLOWED_ACTIONS.key?(action)
      raise ActionController::RoutingError, _('invalid button action')
    end

    send(CATALOG_X_BUTTON_ALLOWED_ACTIONS[action])
  end

  def servicetemplate_edit
    assert_privileges(params[:pressed]) if params[:pressed]
    checked = find_checked_items
    @sb[:cached_waypoint_ids] = MiqAeClass.waypoint_ids_for_state_machines
    checked[0] = params[:id] if checked.blank? && params[:id]
    @record = checked[0] ? find_by_id_filtered(ServiceTemplate, checked[0]) : ServiceTemplate.new
    @sb[:st_form_active_tab] = "basic"
    if checked[0]
      if @record.service_type == "composite"
        st_edit
      else
        atomic_st_edit
      end
    else
      # check for service_type incase add/cancel button was pressed to direct to correct method
      if params[:pressed] == "atomic_catalogitem_new" || (params[:button] && session[:edit][:new][:service_type] == "atomic")
        atomic_st_edit
      else
        st_edit
      end
    end
  end

  def atomic_st_edit
    # reset the active tree back to :sandt_tree, it was changed temporairly to display automate entry point tree in a popup div
    self.x_active_tree = 'sandt_tree'
    case params[:button]
    when "cancel"
      if session[:edit][:rec_id]
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") %
          {:model => ui_lookup(:model => 'ServiceTemplate'), :name => session[:edit][:new][:description]})
      else
        add_flash(_("Add of new %{model} was cancelled by the user") %
          {:model => ui_lookup(:model => 'ServiceTemplate')})
      end
      @edit = @record = nil
      @in_a_form = false
      replace_right_cell
    when "save", "add"
      assert_privileges("atomic_catalogitem_#{params[:button] == "save" ? "edit" : "new"}")
      atomic_req_submit
    when "reset", nil  # Reset or first time in
      @_params[:org_controller] = "service_template"
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      if !@record.id.nil? && need_prov_dialogs?(@record.prov_type)
        prov_set_form_vars(MiqRequest.find(@record.service_resources[0].resource_id))      # Set vars from existing request
        @edit[:new][:st_prov_type] = @record.prov_type
      else
        # prov_set_form_vars
        @edit ||= {}                                    # Set default vars
        @edit[:new] ||= {}
        @edit[:current] ||= {}
        @edit[:key] = "prov_edit__new"
        @edit[:new][:st_prov_type] = @record.prov_type if @record.try(:id)
        @edit[:st_prov_types] = catalog_item_types
      end

      # set name and description for ServiceTemplate record
      set_form_vars
      @edit[:new][:service_type] = "atomic"
      @edit[:rec_id] = @record.try(:id)
      @edit[:current] = copy_hash(@edit[:new])

      @tabactive = @edit[:new][:current_tab_key]
      @in_a_form = true
      session[:changed] = false
      replace_right_cell("at_st_new")
    end
  end

  def catalog_item_types
    {
      "amazon"                => "Amazon",
      "azure"                 => "Azure",
      "generic"               => "Generic",
      "generic_orchestration" => "Orchestration",
      "generic_ansible_tower" => "AnsibleTower",
      "google"                => "Google",
      "microsoft"             => "SCVMM",
      "openstack"             => "OpenStack",
      "redhat"                => "RHEV",
      "vmware"                => "VMware"
    }
  end

  def atomic_form_field_changed
    # need to check req_id in session since we are using common code for prov requests and atomic ST screens
    id = session[:edit][:req_id] || "new"
    return unless load_edit("prov_edit__#{id}", "replace_cell__explorer")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])
    # Build Catalog Items tree unless @edit[:ae_tree_select]
    build_ae_tree(:automate, :automate_tree) if params[:display] || params[:template_id] || params[:manager_id]
    if params[:st_prov_type] # build request screen for selected item type
      @_params[:org_controller] = "service_template"
      prov_set_form_vars if need_prov_dialogs?(params[:st_prov_type])
      @record = class_service_template(params[:st_prov_type]).new
      set_form_vars
      @edit[:new][:st_prov_type] = params[:st_prov_type] if params[:st_prov_type]
      @edit[:new][:service_type] = "atomic"
      default_entry_point(@edit[:new][:st_prov_type]) if params[:st_prov_type].start_with?('generic')
      @edit[:rec_id] = @record ? @record.id : nil
      @tabactive = @edit[:new][:current_tab_key]
    end
    render :update do |page|                    # Use JS to update the display
      # for generic/orchestration type tabs do not show up on screen as there is only a single tab when form is initialized
      # when display in catalog is checked, replace div so tabs can be redrawn
      page.replace("form_div", :partial => "st_form") if params[:st_prov_type] || params[:display]
      page.replace_html("basic_info_div", :partial => "form_basic_info") if params[:display] || params[:template_id] || params[:manager_id]
      if params[:display]
        page << "miq_tabs_show_hide('#details_tab', '#{(params[:display] == "1")}')"
      end
      if changed != session[:changed]
        page << javascript_for_miq_button_visibility(changed)
        session[:changed] = changed
      end
      page << set_spinner_off
    end
  end

  # VM or Template show selected, redirect to proper controller
  def show
    @explorer = true if request.xml_http_request? # Ajax request means in explorer
    record = ServiceTemplate.find_by_id(from_cid(params[:id]))
    if !@explorer
      tree_node_id = TreeBuilder.build_node_id(record)
      redirect_to :controller => "catalog",
                  :action     => "explorer",
                  :id         => tree_node_id
      return
    else
      redirect_to :action => 'show', :controller => record.class.base_model.to_s.underscore, :id => record.id
    end
  end

  def explorer
    @explorer = true
    @lastaction = "explorer"

    # if AJAX request, replace right cell, and return
    if request.xml_http_request?
      replace_right_cell
      return
    end

    build_accordions_and_trees

    if params[:id]  # If a tree node id came in, show in one of the trees
      @nodetype, id = params[:id].split("_").last.split("-")
      self.x_active_tree   = 'sandt_tree'
      self.x_active_accord = 'sandt'
      st = ServiceTemplate.find_by_id(from_cid(params[:id].split("-").last))
      prefix = st.service_template_catalog_id ? "stc-#{to_cid(st.service_template_catalog_id)}_st-" : "-Unassigned_st-"
      add_nodes = open_parent_nodes(st)
      @add_nodes = {}
      @add_nodes[:sandt_tree] = add_nodes if add_nodes  # Set nodes that need to be added, if any
      self.x_node = "#{prefix}#{to_cid(id)}"
      get_node_info(x_node)
    else
      @in_a_form = false
    end

    if params[:commit] == "Upload" && session.fetch_path(:edit, :new, :sysprep_enabled, 1) == "Sysprep Answer File"
      upload_sysprep_file
      set_form_locals_for_sysprep
    end

    render :layout => "application", :action => "explorer"
  end

  def set_form_locals_for_sysprep
    @pages = false
    @edit[:explorer] = true
    @sb[:st_form_active_tab] = "request"
    @right_cell_text = _("Adding a new %{model}") % {:model => ui_lookup(:model => "ServiceTemplate")}
    @x_edit_buttons_locals = {:action_url => "servicetemplate_edit"}
  end

  def identify_catalog(id = nil)
    kls = TreeBuilder.get_model_for_prefix(@nodetype) == "MiqTemplate" ? VmOrTemplate : ServiceTemplate
    @record = identify_record(id || params[:id], kls)
  end

  # ST clicked on in the explorer right cell
  def x_show
    @explorer = true
    if x_active_tree == :stcat_tree
      if params[:rec_id]
        # link to Catalog Item clicked on catalog summary screen
        self.x_active_tree = :sandt_tree
        self.x_active_accord = 'sandt'
        @record = ServiceTemplate.find_by_id(from_cid(params[:rec_id]))
      else
        @record = ServiceTemplateCatalog.find_by_id(from_cid(params[:id]))
      end
    elsif x_active_tree == :ot_tree
      @record ||= OrchestrationTemplate.find_by_id(from_cid(params[:id]))
    else
      identify_catalog(from_cid(params[:id]))
      @record ||= ServiceTemplateCatalog.find_by_id(from_cid(params[:id]))
    end
    params[:id] = x_build_node_id(@record, x_tree(x_active_tree))  # Get the tree node id
    tree_select
  end

  # Tree node selected in explorer
  def tree_select
    @explorer   = true
    @lastaction = "explorer"
    self.x_active_tree = params[:tree] if params[:tree]
    self.x_node        = params[:id]
    replace_right_cell
  end

  # Accordion selected in explorer
  def accordion_select
    @layout     = "explorer"
    @lastaction = "explorer"
    self.x_active_accord = params[:id].sub(/_accord$/, '')
    self.x_active_tree   = "#{x_active_accord}_tree"
    replace_right_cell
  end

  def st_delete
    assert_privileges("catalogitem_delete")
    elements = []
    if params[:id]
      elements.push(params[:id])
      process_sts(elements, 'destroy') unless elements.empty?
      add_flash(_("The selected %{record} was deleted") %
        {:record => ui_lookup(:table => "service_template")}) if @flash_array.nil?
      self.x_node = "root"
    else # showing 1 element, delete it
      elements = find_checked_items
      if elements.empty?
        add_flash(_("No %{model} were selected for deletion") %
          {:model => ui_lookup(:tables => "service_template")}, :error)
      end
      process_sts(elements, 'destroy') unless elements.empty?
      add_flash(_("The selected %{record} were deleted") %
        {:record => pluralize(elements.length, ui_lookup(:table => "service_template"))}) unless flash_errors?
    end
    params[:id] = nil
    replace_right_cell(nil, trees_to_replace([:sandt, :svccat]))
  end

  def st_edit
    # reset the active tree back to :sandt_tree, it was changed temporairly to display automate entry point tree in a popup div
    self.x_active_tree = 'sandt_tree'
    case params[:button]
    when "cancel"
      if session[:edit][:rec_id]
        add_flash(_("Edit of Catalog Bundle \"%{name}\" was cancelled by the user") %
                    {:name => session[:edit][:new][:description]})
      else
        add_flash(_("Add of new Catalog Bundle was cancelled by the user"))
      end
      @edit = @record = nil
      @in_a_form = false
      replace_right_cell
    when "save", "add"
      return unless load_edit("st_edit__#{params[:id] || "new"}", "replace_cell__explorer")
      get_form_vars
      if @edit[:new][:name].blank?
        add_flash(_("Name is required"), :error)
      end

      if @edit[:new][:selected_resources].empty?
        add_flash(_("Resource must be selected"), :error)
      end
      add_flash(_("Provisioning Entry Point is required"), :error) if @edit[:new][:fqname].blank?
      dialog_catalog_check

      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        return
      end
      @st = @edit[:rec_id] ? ServiceTemplate.find_by_id(@edit[:rec_id]) : ServiceTemplate.new
      st_set_record_vars(@st)
      if @add_rsc
        if @st.save
          set_resource_action(@st)
          flash_key = if params[:button] == "save"
                        _("Catalog Bundle \"%{name}\" was saved")
                      else
                        _("Catalog Bundle \"%{name}\" was added")
                      end
          add_flash(flash_key % {:name => @edit[:new][:name]})
          @changed = session[:changed] = false
          @in_a_form = false
          @edit = session[:edit] = @record = nil
          replace_right_cell(nil, trees_to_replace([:sandt, :svccat, :stcat]))
        else
          @st.errors.each do |field, msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @changed = session[:changed] = (@edit[:new] != @edit[:current])
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        end
      else
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        return
      end
    when "reset", nil  # Reset or first time in
      st_set_form_vars
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      @changed = session[:changed] = false
      replace_right_cell("st_new")
      return
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def st_form_field_changed
    return unless load_edit("st_edit__#{params[:id]}", "replace_cell__explorer")
    @group_idx = false
    default_entry_point("generic") if params[:display]
    st_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    build_ae_tree(:automate, :automate_tree) # Build Catalog Items tree
    render :update do |page|                    # Use JS to update the display
      page.replace_html("basic_info_div", :partial => "form_basic_info") if params[:resource_id] || params[:display]
      page.replace_html("resources_info_div", :partial => "form_resources_info") if params[:resource_id] || @group_idx
      if params[:display]
        page << "miq_tabs_show_hide('#details_tab', '#{(params[:display] == "1")}')"
      end
      if changed != session[:changed]
        session[:changed] = changed
        page << "ManageIQ.changes = true;"
        page << javascript_for_miq_button_visibility(changed)
      end
      page << "miqSparkle(false);"
    end
  end

  def st_upload_image
    err = false
    if params[:pressed]
      identify_catalog(params[:id])
      @record.picture = nil
      @record.save
      msg = _("Custom Image successfully removed")
    elsif params[:upload] && params[:upload][:image] &&
          params[:upload][:image].respond_to?(:read)
      identify_catalog(params[:id])
      ext = params[:upload][:image].original_filename.split(".").last.downcase
      if !["png", "jpg"].include?(ext)
        msg = _("Custom Image must be a .png or .jpg file")
        err = true
      else
        @record.picture ||= Picture.new
        @record.picture.content = params[:upload][:image].read
        @record.picture.extension = ext
        @record.save
        msg = _("Custom Image file \"%{name}\" successfully uploaded") %
              {:name => params[:upload][:image].original_filename}
      end
    else
      identify_catalog(params[:id])
      msg = _("Use the Browse button to locate a .png or .jpg image file")
      err = true
    end
    params[:id] = x_build_node_id(@record)  # Get the tree node id
    add_flash(msg, err == true ? :error : nil)
    respond_to do |format|
      format.js { replace_right_cell }
      format.html do                # HTML, send error screen
        explorer
      end
      format.any { head :not_found }  # Anything else, just send 404
    end
  end

  def resource_delete
    return unless load_edit("st_edit__#{params[:id]}", "replace_cell__explorer")
    @edit[:new][:rsc_groups][params[:grp_id].to_i].each do |r|
      if r[:id].to_s == params[:rec_id]
        @edit[:new][:available_resources][r[:resource_id]] = r[:name]       # add it back to available resources pulldown
        @edit[:new][:selected_resources].delete(r[:resource_id])            # delete it from to selected resources
        @edit[:new][:rsc_groups][params[:grp_id].to_i].delete(r)            # delete element from group
        rearrange_provision_order(@edit[:new][:rsc_groups], r[:provision_index])
      end
    end

    # if resource has been deleted from group, rearrange groups incase group is now empty.
    rearrange_groups_array
    build_ae_tree(:automate, :automate_tree) # Build Catalog Items tree
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page.replace_html("basic_info_div", :partial => "form_basic_info")
      page.replace_html("resources_info_div", :partial => "form_resources_info")
      if changed != session[:changed]
        session[:changed] = changed
        page << "ManageIQ.changes = true;"
        page << javascript_for_miq_button_visibility(changed)
      end
      page << "miqSparkle(false);"
    end
  end

  # Edit user or group tags
  def st_tags_edit
    assert_privileges("catalogitem_edit")
    tags_edit("ServiceTemplate")
  end

  # Edit user or group tags
  def ot_tags_edit
    assert_privileges("orchestration_template_tag")
    tags_edit("OrchestrationTemplate")
  end

  # Edit user or group tags
  def tags_edit(klass)
    case params[:button]
    when "cancel"
      x_edit_tags_cancel
    when "save", "add"
      x_edit_tags_save
    when "reset", nil  # Reset or first time in
      x_edit_tags_reset(klass)  # pass in the DB
    end
  end

  def get_ae_tree_edit_key(type)
    case type
    when 'provision'   then :fqname
    when 'retire'      then :retire_fqname
    when 'reconfigure' then :reconfigure_fqname
    end
  end
  private :get_ae_tree_edit_key

  def ae_tree_select_toggle
    @edit = session[:edit]
    self.x_active_tree = :sandt_tree
    at_tree_select_toggle(get_ae_tree_edit_key(@edit[:ae_field_typ]))
    x_node_set(@edit[:active_id], :automate_tree) if params[:button] == 'submit'
    session[:edit] = @edit
  end

  def ae_tree_select_discard
    ae_tree_key = get_ae_tree_edit_key(params[:typ])
    @edit = session[:edit]
    @edit[:new][params[:typ]] = nil
    @edit[:new][ae_tree_key] = ''
    # build_ae_tree(:automate, :automate_tree) # Build Catalog Items tree unless @edit[:ae_tree_select]
    render :update do |page|
      @changed = (@edit[:new] != @edit[:current])
      x_node_set(@edit[:active_id], :automate_tree)
      page << javascript_hide("ae_tree_select_div")
      page << javascript_hide("blocker_div")
      page << javascript_hide("#{ae_tree_key}_div")
      page << "$('##{ae_tree_key}').val('#{@edit[:new][ae_tree_key]}');"
      page << "$('##{ae_tree_key}').prop('title', '#{@edit[:new][ae_tree_key]}');"
      @edit[:ae_tree_select] = false
      page << javascript_for_miq_button_visibility(@changed)
      page << "miqDynatreeActivateNodeSilently('automate_tree', 'root');"
      page << "miqSparkle(false);"
    end
    session[:edit] = @edit
  end

  def ae_tree_select
    @edit = session[:edit]
    at_tree_select(get_ae_tree_edit_key(@edit[:ae_field_typ]))
    session[:edit] = @edit
  end

  def svc_catalog_provision
    assert_privileges("svc_catalog_provision")
    checked = find_checked_items
    checked[0] = params[:id] if checked.blank? && params[:id]
    st = find_by_id_filtered(ServiceTemplate, checked[0])
    @right_cell_text = _("Order %{model} \"%{name}\"") % {:name  => st.name,
                                                          :model => ui_lookup(:model => "Service")}
    ra = nil
    st.resource_actions.each do |r|
      if r.action.downcase == "provision" && r.dialog_id
        # find the first provision action, run the dialog
        ra = r
        break
      end
    end
    if ra
      @explorer = true
      options = {}
      options[:header] = @right_cell_text
      options[:target_id] = st.id
      options[:target_kls] = st.class.name
      dialog_initialize(ra, options)
    else
      # if catalog item has no dialog and provision button was pressed from list view
      add_flash(_("No Ordering Dialog is available"), :warning)
      replace_right_cell
    end
  end

  def st_catalog_edit
    case params[:button]
    when "cancel"
      if session[:edit][:rec_id]
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") %
          {:model => ui_lookup(:model => "ServiceTemplateCatalog"), :name => session[:edit][:new][:name]})
      else
        add_flash(_("Add of new %{model} was cancelled by the user") %
          {:model => ui_lookup(:model => "ServiceTemplateCatalog")})
      end
      @edit = nil
      @in_a_form = false
      replace_right_cell
    when "save", "add"
      assert_privileges("st_catalog_#{params[:id] ? "edit" : "new"}")
      return unless load_edit("st_catalog_edit__#{params[:id] || "new"}", "replace_cell__explorer")

      @stc = @edit[:rec_id] ? ServiceTemplateCatalog.find_by_id(@edit[:rec_id]) : ServiceTemplateCatalog.new
      st_catalog_set_record_vars(@stc)
      begin
        @stc.save
      rescue StandardError => bang
        add_flash(_("Error during 'Catalog Edit': %{error_message}") % {:error_message => bang.message}, :error)
      else
        if @stc.errors.empty?
          add_flash(_("%{model} \"%{name}\" was saved") %
                      {:model => ui_lookup(:model => 'ServiceTemplateCatalog'),
                       :name  => @edit[:new][:name]})
        else
          @stc.errors.each do |field, msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
          return
        end
      end
      @changed = session[:changed] = false
      @in_a_form = false
      @edit = session[:edit] = nil
      replace_right_cell(nil, trees_to_replace([:sandt, :svccat, :stcat]))
    when "reset", nil  # Reset or first time in
      st_catalog_set_form_vars
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      @changed = session[:changed] = false
      replace_right_cell("st_catalog_edit")
      return
    end
  end

  def st_catalog_form_field_changed
    id = session[:edit][:rec_id] || "new"
    return unless load_edit("st_catalog_edit__#{id}", "replace_cell__explorer")
    st_catalog_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page.replace(@refresh_div, :partial => @refresh_partial) if @refresh_div
      page << javascript_for_miq_button_visibility(changed)
      page << "miqSparkle(false);"
    end
  end

  def process_sts(sts, task, _display_name = nil)
    ServiceTemplate.where(:id => sts).order("lower(name)").each do |st|
      id = st.id
      st_name = st.name
      audit = {:event        => "st_record_delete",
               :message      => _("[%{name}] Record deleted") % {:name => st_name},
               :target_id    => id,
               :target_class => "ServiceTemplate",
               :userid       => session[:userid]}
      model_name = ui_lookup(:model => "ServiceTemplate")  # Lookup friendly model name in dictionary
      begin
        st.public_send(task.to_sym) if st.respond_to?(task)    # Run the task
      rescue StandardError => bang
        add_flash(_("%{model} \"%{name}\": Error during '%{task}': %{error_message}") %
          {:model => model_name, :name => st_name, :task => task, :error_message => bang.message}, :error)
      else
        AuditEvent.success(audit)
      end
    end
  end
  private :process_sts

  def template_to_node_name(object)
    ORCHESTRATION_TEMPLATES_NODES[object.class.name]
  end

  def node_name_to_template_name(node_name)
    node_elems = node_name.split('-')
    if node_elems[1]
      ORCHESTRATION_TEMPLATES_NODES.invert[node_elems[1]]
    end
  end

  def ot_edit
    assert_privileges("orchestration_template_edit")
    checked = find_checked_items
    checked[0] = params[:id] if checked.blank? && params[:id]
    @record = find_by_id_filtered(OrchestrationTemplate, checked[0])
    if @record.in_use?
      add_flash(_("Orchestration template \"%{name}\" is read-only and cannot be edited.") %
        {:name => @record.name}, :error)
      get_node_info(x_node)
      replace_right_cell(x_node)
      return
    end
    ot_edit_set_form_vars(_("Editing %s"))
    replace_right_cell("ot_edit")
  end

  def ot_copy
    assert_privileges("orchestration_template_copy")
    ot_edit_set_form_vars(_("Copying %s"))
    @edit[:new][:name] = @edit[:current][:name] = _("Copy of %{name}") % {:name => @edit[:new][:name]}
    replace_right_cell("ot_copy")
  end

  def ot_edit_submit
    self.x_active_tree = 'ot_tree'
    case params[:button]
    when "cancel"
      ot_edit_submit_cancel
    when "save"
      ot_edit_submit_save
    when "reset"
      ot_edit_submit_reset
    end
  end

  def ot_form_field_changed
    id = params[:id]
    return unless load_edit("ot_edit__#{id}", "replace_cell__explorer")
    ot_edit_get_form_vars
    render :update do |page|
      page << javascript_hide("buttons_off")
      page << javascript_show("buttons_on")
    end
  end

  def ot_copy_submit
    case params[:button]
    when "cancel"
      ot_copy_submit_cancel
    when "add"
      ot_copy_submit_add
    end
  end

  def ot_remove_submit
    assert_privileges("orchestration_template_remove")
    checked = find_checked_items
    checked[0] = params[:id] if checked.blank? && params[:id]
    elements = OrchestrationTemplate.where(:id => checked)
    elements.each do |ot|
      if ot.stacks.length > 0
        add_flash(_("Orchestration template \"%{name}\" is read-only and cannot be deleted.") %
          {:name => ot.name}, :error)
      else
        begin
          ot.delete
        rescue StandardError => bang
          add_flash(_("Error during 'Orchestration Template Deletion': %{error_message}") %
            {:error_message => bang.message}, :error)
        else
          add_flash(_("Orchestration Template \"%{name}\" was deleted.") % {:name => ot.name})
        end
      end
    end
    if elements.length > 1
      self.x_node = 'root'
    else
      self.x_node = "xx-#{template_to_node_name(elements[0])}"
    end
    replace_right_cell(nil, trees_to_replace([:ot]))
  end

  def ot_add
    assert_privileges("orchestration_template_add")
    ot_type = x_node == "root" ? "OrchestrationTemplateCfn" : node_name_to_template_name(x_node)
    @edit = {:new => {:name        => "",
                      :description => "",
                      :content     => "",
                      :type        => ot_type,
                      :draft       => false}}
    @edit[:current] = @edit[:new].dup
    @edit[:key] = "ot_add__new"
    @right_cell_text = _("Adding a new Orchestration Template")
    @in_a_form = true
    replace_right_cell("ot_add")
  end

  def ot_add_submit
    case params[:button]
    when "cancel"
      ot_add_submit_cancel
    when "add"
      ot_add_submit_save
    end
  end

  def ot_add_form_field_changed
    return unless load_edit("ot_add__new", "replace_cell__explorer")
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:type] = params[:type] if params[:type]
    @edit[:new][:content] = params[:content] if params[:content]
    @edit[:new][:draft] = params[:draft] == "true" ? true : false if params[:draft]
    render :update do |page|
      page << javascript_hide("buttons_off")
      page << javascript_show("buttons_on")
      page << "miqSparkle(false);"
    end
  end

  def service_dialog_from_ot
    assert_privileges("service_dialog_from_ot")
    ot = OrchestrationTemplate.find_by_id(params[:id])
    @right_cell_text = _("Adding a new Service Dialog from Orchestration Template \"%{name}\"") % {:name => ot.name}
    @edit = {:new    => {:dialog_name => ""},
             :key    => "ot_edit__#{ot.id}",
             :rec_id => ot.id}
    @in_a_form = true
    replace_right_cell("service_dialog_from_ot")
  end

  def service_dialog_from_ot_submit
    case params[:button]
    when "cancel"
      service_dialog_from_ot_submit_cancel
    when "save"
      service_dialog_from_ot_submit_save
    end
  end

  def ot_show
    assert_privileges("orchestration_templates_view")
    id = params.delete(:id)
    ot = OrchestrationTemplate.find_by_id(id)
    self.x_active_tree = :ot_tree
    self.x_active_accord = 'ot'
    x_tree_init(:ot_tree, :ot, "OrchestrationTemplate") unless x_tree
    ot_type = template_to_node_name(ot)
    x_tree[:open_nodes].push("xx-#{ot_type}") unless x_tree[:open_nodes].include?("xx-#{ot_type}")
    self.x_node = "ot-#{to_cid(ot.id)}"
    x_tree[:open_nodes].push(x_node)
    explorer
  end

  private

  def features
    [{:role     => "svc_catalog_accord",
      :role_any => true,
      :name     => :svccat,
      :title    => _("Service Catalogs")},

     {:role     => "catalog_items_accord",
      :role_any => true,
      :name     => :sandt,
      :title    => _("Catalog Items")},

     {:role     => "orchestration_templates_accord",
      :role_any => true,
      :name     => :ot,
      :title    => _("Orchestration Templates")},

     {:role     => "st_catalog_accord",
      :role_any => true,
      :name     => :stcat,
      :title    => _("Catalogs")},
    ].map do |hsh|
      ApplicationController::Feature.new_with_hash(hsh)
    end
  end

  def class_service_template(prov_type)
    prov_type.starts_with?('generic') ?
      prov_type.gsub(/(generic)(_.*)?/, 'service_template\2').classify.constantize :
      ServiceTemplate
  end

  def atomic_req_submit
    id = session[:edit][:req_id] || "new"
    return unless load_edit("prov_edit__#{id}", "show_list")
    if @edit[:new][:name].blank?
      # check for service template required fields before creating a request
      add_flash(_("Name is required"), :error)
    end
    add_flash(_("Provisioning Entry Point is required"), :error) if @edit[:new][:fqname].blank?

    # Check for a Dialog if Display in Catalog is selected
    dialog_catalog_check

    # Check the validity of the entry points
    %w(fqname reconfigure_fqname retire_fqname).each do |fqname|
      if @edit[:new][fqname.to_sym].present? &&
         MiqAeClass.find_homonymic_instances_across_domains(current_user, @edit[:new][fqname.to_sym]).empty?
        level = :error
        msg = _('Please correct invalid %{adjective} Entry Point prior to saving')
        case fqname
        when 'fqname'
          add_flash(msg % {:adjective => _("Provisioning")}, level)
        when 'reconfigure_fqname'
          add_flash(msg % {:adjective => _("Reconfigure")}, level)
        when 'retire_fqname'
          add_flash(msg % {:adjective => _("Retirement")}, level)
        end
      end
    end

    # set request for non generic ST
    if @edit[:wf] && need_prov_dialogs?(@edit[:new][:st_prov_type])
      request = @edit[:wf].make_request(@edit[:req_id], @edit[:new])
      if request && request.errors.present?
        request.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
      else
        validate_fields
      end
    end

    if @flash_array
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
      return
    end
    get_form_vars   # need to get long_description
    st = @edit[:rec_id] ?
      ServiceTemplate.find_by_id(@edit[:rec_id]) :
      class_service_template(@edit[:new][:st_prov_type]).new
    common_st_record_vars(st)
    add_orchestration_template_vars(st) if st.kind_of?(ServiceTemplateOrchestration)
    add_ansible_tower_job_template_vars(st) if st.kind_of?(ServiceTemplateAnsibleTower)
    st.service_type = "atomic"

    if request
      st.remove_all_resources
      st.add_resource(request) if need_prov_dialogs?(@edit[:new][:st_prov_type])
    end

    if st.save
      set_resource_action(st)
      flash_key = params[:button] == "save" ? _("%{model} \"%{name}\" was saved") : _("%{model} \"%{name}\" was added")
      add_flash(flash_key % {:model => ui_lookup(:model => "ServiceTemplate"), :name => @edit[:new][:name]})
      @changed = session[:changed] = false
      @in_a_form = false
      @edit = session[:edit] = @record = nil
      replace_right_cell(nil, trees_to_replace([:sandt, :svccat, :stcat]))
    else
      st.errors.each do |field, msg|
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
      end
      @changed = session[:changed] = (@edit[:new] != @edit[:current])
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    end
  end

  def service_template_list(condition, options = {})
    @no_checkboxes = x_active_tree == :svccat_tree
    if x_active_tree == :svccat_tree
      @gtl_buttons = ["view_list", "view_tile"]
      @gtl_small_tiles = true
      if role_allows(:feature => 'svc_catalog_provision')
        @row_button = {:label    => _("Order"),
                       :function => "miqOrderService",
                       :title    => _("Order this Service")} # Show a button instead of the checkbox
      end
    end
    options[:model] = "ServiceCatalog" unless options[:model]
    options[:where_clause] = condition
    process_show_list(options)
  end

  def ot_edit_get_form_vars
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:draft] = params[:draft] == "true" ? true : false if params[:draft]
    @edit[:new][:dialog_name] = params[:dialog_name] if params[:dialog_name]
  end

  def ot_edit_set_form_vars(right_cell_text)
    checked = find_checked_items
    checked[0] = params[:id] if checked.blank? && params[:id]
    @record = checked[0] ? find_by_id_filtered(OrchestrationTemplate, checked[0]) : OrchestrationTemplate.new
    @edit = {:current => {:name        => @record.name,
                          :description => @record.description,
                          :content     => @record.content,
                          :draft       => @record.draft},
             :rec_id  => @record.id}
    @edit[:new] = @edit[:current].dup
    @edit[:key] = "ot_edit__#{@record.id}"
    @right_cell_text = right_cell_text % @record.name
    @in_a_form = true
  end

  def ot_edit_submit_cancel
    add_flash(_("Edit of Orchestration Template \"%{name}\" was cancelled by the user") %
      {:name => session[:edit][:new][:name]})
    @in_a_form = false
    @edit = @record = nil
    replace_right_cell
  end

  def ot_edit_submit_save
    assert_privileges("orchestration_template_edit")
    id = params[:id]
    return unless load_edit("ot_edit__#{id}", "replace_cell__explorer")
    if params.key?(:template_content) && params[:template_content] == ""
      add_flash(_("New template content cannot be empty"), :error)
      ot_action_submit_flash
    else
      ot = OrchestrationTemplate.find_by_id(@edit[:rec_id])
      ot.name = @edit[:new][:name]
      ot.description = @edit[:new][:description]
      if ot.stacks.length == 0
        ot.content = params[:template_content]
        ot.draft = @edit[:new][:draft]
      end
      begin
        ot.save_as_orderable!
      rescue StandardError => bang
        add_flash(_("Error during 'Orchestration Template Edit': %{error_message}") %
          {:error_message => bang.message}, :error)
        ot_action_submit_flash
      else
        add_flash(_("%{model} \"%{name}\" was saved") %
                  {:model => ui_lookup(:model => 'OrchestrationTemplate'),
                   :name  => @edit[:new][:name]})
        @changed = session[:changed] = false
        @in_a_form = false
        @edit = session[:edit] = nil
        replace_right_cell(nil, trees_to_replace([:ot]))
      end
    end
  end

  def ot_edit_submit_reset
    add_flash(_("All changes have been reset"), :warning)
    ot_edit_set_form_vars(_("Editing %s"))
    @changed = session[:changed] = false
    replace_right_cell("ot_edit")
  end

  def ot_copy_submit_cancel
    add_flash(_("Copy of Orchestration Template \"%{name}\" was cancelled by the user") %
      {:name => session[:edit][:current][:name]})
    @in_a_form = false
    @edit = @record = nil
    replace_right_cell
  end

  def ot_copy_submit_add
    assert_privileges("orchestration_template_copy")
    id = params[:original_ot_id]
    return unless load_edit("ot_edit__#{id}", "replace_cell__explorer")
    old_ot = OrchestrationTemplate.find_by_id(id)
    if params[:template_content] == old_ot.content
      add_flash(
        _("Unable to create a new template copy \"%{name}\": old and new template content have to differ.") %
          {:name => @edit[:new][:name]}, :error)
      ot_action_submit_flash
    elsif params[:template_content].nil? || params[:template_content] == ""
      add_flash(_("Unable to create a new template copy \"%{name}\": new template content cannot be empty.") %
        {:name => @edit[:new][:name]}, :error)
      ot_action_submit_flash
    else
      ot = OrchestrationTemplate.new(
        :name        => @edit[:new][:name],
        :description => @edit[:new][:description],
        :type        => old_ot.type,
        :content     => params[:template_content],
        :draft       => @edit[:new][:draft] == true || @edit[:new][:draft] == "true")
      begin
        ot.save_as_orderable!
      rescue StandardError => bang
        add_flash(_("Error during 'Orchestration Template Copy': %{error_message}") %
          {:error_message => bang.message}, :error)
        ot_action_submit_flash
      else
        add_flash(_("%{model} \"%{name}\" was saved") %
                    {:model => ui_lookup(:model => 'OrchestrationTemplate'),
                     :name  => @edit[:new][:name]})
        x_node_elems = x_node.split('-')
        if !x_node_elems[2].nil? && x_node_elems[2] != to_cid(ot.id)
          x_node_elems[2] = to_cid(ot.id)
          self.x_node = x_node_elems.join('-')
        end

        @changed = session[:changed] = false
        @in_a_form = false
        @edit = session[:edit] = nil
        replace_right_cell(nil, trees_to_replace([:ot]))
      end
    end
  end

  def ot_add_submit_cancel
    add_flash(_("Creation of a new Orchestration Template was cancelled by the user"))
    @in_a_form = false
    @edit = @record = nil
    replace_right_cell
  end

  def ot_add_submit_save
    assert_privileges("orchestration_template_add")
    load_edit("ot_add__new", "replace_cell__explorer")
    if !%w(OrchestrationTemplateHot OrchestrationTemplateCfn OrchestrationTemplateAzure).include?(@edit[:new][:type])
      add_flash(_("\"%{type}\" is not a valid Orchestration Template type") % {:type => @edit[:new][:type]}, :error)
      ot_action_submit_flash
    elsif params[:content].nil? || params[:content].strip == ""
      add_flash(_("Error during Orchestration Template creation: new template content cannot be empty"), :error)
      ot_action_submit_flash
    else
      ot = OrchestrationTemplate.new(
        :name        => @edit[:new][:name],
        :description => @edit[:new][:description],
        :type        => @edit[:new][:type],
        :content     => params[:content],
        :draft       => @edit[:new][:draft])
      begin
        ot.save_as_orderable!
      rescue StandardError => bang
        add_flash(_("Error during 'Orchestration Template creation': %{error_message}") %
          {:error_message => bang.message}, :error)
        ot_action_submit_flash
      else
        add_flash(_("%{model} \"%{name}\" was saved") %
                    {:model => ui_lookup(:model => 'OrchestrationTemplate'),
                     :name  => @edit[:new][:name]})
        subtree = template_to_node_name(ot)
        x_tree[:open_nodes].push(subtree) unless x_tree[:open_nodes].include?(subtree)
        ot_type = template_to_node_name(ot)
        self.x_node = "xx-%{type}_ot-%{cid}" % {:type => ot_type,
                                                :cid  => to_cid(ot.id)}
        x_tree[:open_nodes].push(x_node)
        @changed = session[:changed] = false
        @in_a_form = false
        @edit = session[:edit] = nil
        replace_right_cell(nil, trees_to_replace([:ot]))
      end
    end
  end

  def ot_action_submit_flash
    render :update do |page|
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
    end
  end

  def service_dialog_from_ot_submit_cancel
    add_flash(_("Creation of a new Service Dialog was cancelled by the user"))
    @in_a_form = false
    @edit = @record = nil
    replace_right_cell
  end

  def service_dialog_from_ot_submit_save
    assert_privileges("service_dialog_from_ot")
    load_edit("ot_edit__#{params[:id]}", "replace_cell__explorer")
    begin
      ot = OrchestrationTemplate.find_by_id(params[:id])
      OrchestrationTemplateDialogService.new.create_dialog(@edit[:new][:dialog_name], ot)
    rescue => bang
      add_flash(_("Error when creating a Service Dialog from Orchestration Template: %{error_message}") %
        {:error_message => bang.message}, :error)
      render :update do |page|
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    else
      add_flash(_("Service Dialog \"%{name}\" was successfully created") %
        {:name => @edit[:new][:dialog_name]}, :success)
      @in_a_form = false
      @edit = @record = nil
      replace_right_cell
    end
  end

  def st_catalog_get_form_vars
    if params[:button]
      move_cols_left_right("right") if params[:button] == "right"
      move_cols_left_right("left") if params[:button] == "left"
    else
      @edit[:new][:name] = params[:name] if params[:name]
      @edit[:new][:description]  = params[:description] if params[:description]
    end
  end

  def st_catalog_set_form_vars
    checked = find_checked_items
    checked[0] = params[:id] if checked.blank? && params[:id]

    @record = checked[0] ? find_by_id_filtered(ServiceTemplateCatalog, checked[0]) : ServiceTemplateCatalog.new
    @right_cell_text = @record.id ?
        _("Editing %{model} \"%{name}\"") % {:name => @record.name, :model => ui_lookup(:model => "ServiceTemplateCatalog")} :
        _("Adding a new %{model}") % {:model => ui_lookup(:model => "ServiceTemplateCatalog")}
    @edit = {}
    @edit[:key] = "st_catalog_edit__#{@record.id || "new"}"
    @edit[:new] = {}
    @edit[:current] = {}
    @edit[:rec_id] = @record.id
    @edit[:new][:name] = @record.name
    @edit[:new][:description]  = @record.description
    @edit[:new][:fields] = @record.service_templates.collect { |st| [st.name, st.id] }.sort

    @edit[:new][:available_fields] = ServiceTemplate.all
                                     .select  { |st| st.service_template_catalog.nil? && st.display }
                                     .collect { |st| [st.name, st.id] }
                                     .sort

    @edit[:current] = copy_hash(@edit[:new])
    @in_a_form = true
  end

  def st_catalog_set_record_vars(stc)
    stc.name = @edit[:new][:name]
    stc.description = @edit[:new][:description]
    stc.service_templates = @edit[:new][:fields].collect { |sf| ServiceTemplate.find_by_id(sf[1]) }
  end

  def st_catalog_delete
    assert_privileges("st_catalog_delete")
    elements = []
    if params[:id]
      elements.push(params[:id])
      process_elements(elements, ServiceTemplateCatalog, "destroy") unless elements.empty?
      self.x_node = "root"
    else # showing 1 element, delete it
      elements = find_checked_items
      if elements.empty?
        add_flash(_("No %{model} were selected for deletion") %
          {:model => ui_lookup(:models => "ServiceTemplateCatalog")}, :error)
      end
      process_elements(elements, ServiceTemplateCatalog, "destroy") unless elements.empty?
    end
    params[:id] = nil
    replace_right_cell(nil, trees_to_replace([:sandt, :svccat, :stcat]))
  end

  def trees_to_replace(trees)
    trees_to_replace = []
    trees_to_replace.push(:stcat) if trees.include?(:stcat) && role_allows(:feature => "st_catalog_accord")
    trees_to_replace.push(:sandt) if trees.include?(:sandt) && role_allows(:feature => "catalog_items_view")
    trees_to_replace.push(:svccat) if trees.include?(:svccat) && role_allows(:feature => "svc_catalog_accord")
    trees_to_replace.push(:ot) if trees.include?(:ot) &&
                                  role_allows(:feature => "orchestration_templates_accord", :any => true)
    trees_to_replace
  end

  def set_resource_action(st)
    d = @edit[:new][:dialog_id].nil? ? nil : Dialog.where(:id => @edit[:new][:dialog_id]).first
    actions = [
      {:name => 'Provision', :edit_key => :fqname},
      {:name => 'Reconfigure', :edit_key => :reconfigure_fqname},
      {:name => 'Retirement', :edit_key => :retire_fqname}
    ]
    actions.each do |action|
      ra = st.resource_actions.find_by_action(action[:name])
      if ra.nil? && !@edit[:new][action[:edit_key]].blank?
        attrs = {:action => action[:name]}
        ra = st.resource_actions.build(attrs)
      end
      if @edit[:new][action[:edit_key]].blank?
        st.resource_actions.where(:action => action[:name]).first.try(:destroy)
      else
        ra.update_attributes(:dialog => d, :fqname => @edit[:new][action[:edit_key]])
      end
    end
  end

  # sets record variables common to both atomic and composite service templates
  def common_st_record_vars(st)
    st.name = @edit[:new][:name]
    st.description = @edit[:new][:description]
    st.long_description = @edit[:new][:display] ? @edit[:new][:long_description] : nil
    st.provision_cost = @edit[:new][:provision_cost]
    st.display = @edit[:new][:display]
    st.service_template_catalog = @edit[:new][:catalog_id].nil? ?
      nil : ServiceTemplateCatalog.find_by_id(@edit[:new][:catalog_id])
    st.prov_type = @edit[:new][:st_prov_type]
  end

  def st_set_record_vars(st)
    common_st_record_vars(st)
    st.remove_all_resources
    @add_rsc = true
    unless @edit[:new][:selected_resources].empty?
      @edit[:new][:selected_resources].each do |r|
        rsc = ServiceTemplate.find_by_id(r)
        @edit[:new][:rsc_groups].each_with_index do |groups, i|
          groups.each do |sr|
            options = {}
            options[:group_idx] = i
            options[:provision_index] = sr[:provision_index]
            options[:start_action] = sr[:start_action]
            options[:stop_action] = sr[:stop_action]
            options[:start_delay] = sr[:start_delay].to_i
            options[:stop_delay] = sr[:stop_delay].to_i
            options[:scaling_min] = sr[:scaling_min].to_i
            options[:scaling_max] = sr[:scaling_max].to_i
            if sr[:resource_id].to_s == rsc.id.to_s
              begin
                st.add_resource(rsc, options)
              rescue MiqException::MiqServiceCircularReferenceError => bang
                @add_rsc = false
                add_flash(_("Error during 'Resource Add': %{error_message}") %
                  {:error_message => bang.message}, :error)
                break
              else
              end
            end
          end
        end
      end
    end
  end

  # common code for both st/at get_form_vars
  def set_form_vars
    @edit[:new][:name] = @record.name
    @edit[:new][:description]  = @record.description
    @edit[:new][:long_description] = @record.long_description
    @edit[:new][:provision_cost] = @record.provision_cost
    @edit[:new][:display]  = @record.display ? @record.display : false
    @edit[:new][:catalog_id] = @record.service_template_catalog ? @record.service_template_catalog.id : nil
    @edit[:new][:available_catalogs] = ServiceTemplateCatalog.all
                                       .collect { |stc| [stc.name, stc.id] }
                                       .sort
    available_orchestration_templates if @record.kind_of?(ServiceTemplateOrchestration)
    available_ansible_tower_managers if @record.kind_of?(ServiceTemplateAnsibleTower)

    # initialize fqnames
    @edit[:new][:fqname] = @edit[:new][:reconfigure_fqname] = @edit[:new][:retire_fqname] = ""
    @record.resource_actions.each do |ra|
      @edit[:new][:dialog_id] = ra.dialog_id.to_i
      if ra.action.downcase == "provision"
        @edit[:new][:fqname] = ra.fqname
      elsif ra.action.downcase == 'reconfigure'
        @edit[:new][:reconfigure_fqname] = ra.fqname
      elsif ra.action.downcase == "retirement"
        @edit[:new][:retire_fqname] = ra.fqname
      end
    end
    get_available_dialogs
    if @record.id.blank?
      @right_cell_text = _("Adding a new %{model}") % {:model => ui_lookup(:model => "ServiceTemplate")}
    else
      @right_cell_text = _("Editing %{model} \"%{name}\"") % {:name => @record.name, :model => ui_lookup(:model => "ServiceTemplate")}
    end
    build_ae_tree(:automate, :automate_tree) # Build Catalog Items tree
  end

  def st_set_form_vars
    @edit = {}
    @edit[:rec_id]   = @record.id
    @edit[:key]     = "st_edit__#{@record.id || "new"}"
    @edit[:url] = "servicetemplate_edit"
    @edit[:new]     = {}
    @edit[:current] = {}
    set_form_vars
    @edit[:new][:service_type] = "composite"
    @edit[:new][:rsc_groups] = []
    @edit[:new][:selected_resources] = []

    len = @record.service_resources.size
    len.times do |l|
      if @record.group_has_resources?(l)
        @edit[:new][:rsc_groups][l] ||= []
        @record.each_group_resource(l) do |sr|
          @edit[:new][:selected_resources].push(sr.resource_id)
          # storing keys that are needed in ui in hash instead of storing an object
          r = {}
          r[:name] = sr.resource_name
          r[:id] = sr.id
          r[:resource_id] = sr.resource_id
          r[:start_action] = sr.start_action ? sr.start_action : "Power On"
          r[:stop_action] = sr.stop_action ? sr.stop_action : "Shutdown"
          r[:start_delay] = sr.start_delay ? sr.start_delay : 0
          r[:stop_delay] = sr.stop_delay ? sr.stop_delay : 0
          r[:scaling_min] = sr.scaling_min ? sr.scaling_min : 1
          r[:scaling_max] = sr.scaling_max ? sr.scaling_max : sr.scaling_min
          r[:provision_index] = sr.provision_index ? sr.provision_index : 0
          @edit[:new][:rsc_groups][l].push(r)
        end
      end
    end
    # add one extra group to show in pulldown so resources can be moved into it.
    @edit[:new][:rsc_groups].push([]) if @edit[:new][:selected_resources].length > 1
    @edit[:new][:provision_order] = recalculate_provision_order

    @edit[:new][:available_resources] = {}
    get_available_resources("ServiceTemplate")
    get_available_dialogs
    @edit[:current] = copy_hash(@edit[:new])
    if @record.id.blank?
      @right_cell_text = _("Adding a new Catalog Bundle")
    else
      @right_cell_text = _("Editing Catalog Bundle \"%{name}\"") % {:name => @record.name}
    end

    @in_a_form = true
  end

  def rearrange_groups_array
    # delete any empty groups, break if found a populated group
    len = @edit[:new][:rsc_groups].length
    # keep count of how many groups are deleted
    g_idx = 0
    # flag to check whether an empty group was deleted so next group elements can be moved up
    arr_delete = false

    @edit[:new][:rsc_groups].each_with_index do |group, i|
      if group.empty?
        g_idx = i
        arr_delete = true
      else
        # update group_idx of resources in group incase previous one got deleted
        @edit[:new][:rsc_groups].delete_at(g_idx) if arr_delete
        arr_delete = false
        g_idx = 0
      end
    end
    # delete any empty groups at the end of the groups array and leave only 1 empty group
    # i.e if on screen resources were assigned to group 1 & 2, pulldown had 1,2,3 in it, now if all resources were moved to group 1, get rid of 3 from pulldown
    prev = 0
    @edit[:new][:rsc_groups].each_with_index do |g, i|
      if i == 0
        prev = g
      end
      if i > 0 && prev.empty? && g.empty?
        @edit[:new][:rsc_groups].delete_at(i)
      end
      prev = g
    end

    # add another empty element to groups array if it doesn't exist to keep one extra in group pulldown
    @edit[:new][:rsc_groups].push([]) if @edit[:new][:selected_resources].length > 1 && !@edit[:new][:rsc_groups][@edit[:new][:rsc_groups].length - 1].empty?
  end

  def get_available_resources(kls)
    @edit[:new][:available_resources] = {}
    kls.constantize.all.each do |r|
      @edit[:new][:available_resources][r.id] = r.name if  r.id.to_s != @edit[:rec_id].to_s &&
                                                           !@edit[:new][:selected_resources].include?(r.id)  # don't add the servicetemplate record that's being edited, or add all vm templates
    end
  end

  def default_entry_point(prov_type)
    edit_new = @edit[:new]
    klass = class_service_template(prov_type)
    edit_new[:fqname] = klass.default_provisioning_entry_point
    edit_new[:retire_fqname] = klass.default_retirement_entry_point if klass.respond_to?(:default_retirement_entry_point)
    edit_new[:reconfigure_fqname] = klass.default_reconfiguration_entry_point if klass.respond_to?(:default_reconfiguration_entry_point)
  end

  def get_form_vars
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description]  = params[:description] if params[:description]
    @edit[:new][:provision_cost]  = params[:provision_cost] if params[:provision_cost]
    @edit[:new][:display]  = params[:display] == "1" if params[:display]
    @edit[:new][:catalog_id] = params[:catalog_id] if params[:catalog_id]
    @edit[:new][:dialog_id] = params[:dialog_id] if params[:dialog_id]
    # saving it in @edit as well, to use it later because prov_set_form_vars resets @edit[:new]
    @edit[:st_prov_type] = @edit[:new][:st_prov_type] = params[:st_prov_type] if params[:st_prov_type]
    @edit[:new][:long_description] = params[:long_description] if params[:long_description]
    @edit[:new][:long_description] = @edit[:new][:long_description].to_s + "..." if params[:transOne]

    get_form_vars_orchestration if @edit[:new][:st_prov_type] == 'generic_orchestration'
    get_form_vars_ansible_tower if @edit[:new][:st_prov_type] == 'generic_ansible_tower'
  end

  def get_form_vars_orchestration
    if params[:template_id]
      if params[:template_id] == ""
        @edit[:new][:available_managers] = []
        @edit[:new][:template_id]        = nil
        @edit[:new][:manager_id]         = nil
      else
        @edit[:new][:template_id] = params[:template_id]
        available_orchestration_managers(params[:template_id])
      end
    end
    @edit[:new][:manager_id] = params[:manager_id] if params[:manager_id]
  end

  def get_form_vars_ansible_tower
    if params[:manager_id]
      if params[:manager_id] == ""
        @edit[:new][:available_templates] = []
        @edit[:new][:template_id]         = nil
        @edit[:new][:manager_id]          = nil
      else
        @edit[:new][:manager_id] = params[:manager_id]
        available_ansible_tower_job_templates(params[:manager_id])
      end
    end
    @edit[:new][:template_id] = params[:template_id] if params[:template_id]
  end

  def available_orchestration_managers(template_id)
    @edit[:new][:available_managers] = OrchestrationTemplate.find_by_id(template_id)
                                       .eligible_managers
                                       .collect { |m| [m.name, m.id] }
                                       .sort
  end

  def available_orchestration_templates
    @edit[:new][:available_templates] = OrchestrationTemplate.available
                                        .collect { |t| [t.name.to_s, t.id] }
                                        .sort
    @edit[:new][:template_id] = @record.orchestration_template.try(:id)
    @edit[:new][:manager_id] = @record.orchestration_manager.try(:id)
    available_orchestration_managers(@record.orchestration_template.id) if @record.orchestration_template
  end

  def available_ansible_tower_job_templates(manager_id)
    @edit[:new][:available_templates] =
      ExtManagementSystem.find_by(:id => manager_id).configuration_scripts.collect { |t| [t.name, t.id] }.sort
  end

  def available_ansible_tower_managers
    @edit[:new][:available_managers] =
      ManageIQ::Providers::AnsibleTower::ConfigurationManager.all.collect { |t| [t.name, t.id] }.sort
    @edit[:new][:template_id] = @record.job_template.try(:id)
    @edit[:new][:manager_id] = @record.job_template.try(:manager).try(:id)
    available_ansible_tower_job_templates(@edit[:new][:manager_id]) if @edit[:new][:manager_id]
  end

  def add_orchestration_template_vars(st)
    st.orchestration_template = @edit[:new][:template_id].nil? ?
      nil : OrchestrationTemplate.find_by_id(@edit[:new][:template_id])
    st.orchestration_manager  = @edit[:new][:manager_id].nil? ?
      nil : ExtManagementSystem.find_by_id(@edit[:new][:manager_id])
  end

  def add_ansible_tower_job_template_vars(st)
    st.job_template = @edit[:new][:template_id].nil? ?
      nil : ConfigurationScript.find_by(:id => @edit[:new][:template_id])
  end

  def st_get_form_vars
    get_form_vars
    if params[:resource_id]
      # adding new service resource, so need to lookup actual vm or service template record and set defaults
      sr = ServiceTemplate.find_by_id(params[:resource_id])
      # storing keys that are needed in ui in hash instead of storing an object
      r = {}
      r[:name] = sr.name
      r[:id] = sr.id
      r[:resource_id] = sr.id
      r[:start_action] = "Power On"
      r[:stop_action] = "Shutdown"
      r[:start_delay] = 0
      r[:stop_delay] = 0
      r[:scaling_min] = 1
      r[:scaling_max] = r[:scaling_min]
      r[:provision_index] = 0
      @edit[:new][:selected_resources].push(sr.id) unless @edit[:new][:selected_resources].include?(sr.id)
      @edit[:new][:rsc_groups][0] ||= [] # initialize array is adding new record

      # add another empty element to groups array if it doesn't exist to keep one extra in group pulldown
      @edit[:new][:rsc_groups].push([]) if @edit[:new][:selected_resources].length > 1 && !@edit[:new][:rsc_groups][@edit[:new][:rsc_groups].length - 1].empty?

      # push a new resource into highest existing/populated group
      @edit[:new][:rsc_groups].each_with_index do |g, i|
        if g.empty?
          id = i == 0 ? 0 : i - 1
          @edit[:new][:rsc_groups][id].push(r) unless @edit[:new][:rsc_groups][id].include?(r)
          break
        end
      end
      @edit[:new][:provision_order] = recalculate_provision_order
    else
      # check if group idx change transaction came in
      params.each do |var, val|
        vars = var.split("_")
        if vars[0] == "gidx"
          rid = from_cid(vars[1])
          # push a new resource into highest existing/populated group
          @group_changed = false
          @edit[:new][:rsc_groups].each_with_index do |groups, i|
            groups.each do |g|
              if g[:id] == rid
                @edit[:new][:rsc_groups][val.to_i - 1].push(g)
                @edit[:new][:rsc_groups][i].delete(g)
                @group_changed = true
                break
              end
            end
            break if @group_changed
          end

          rearrange_groups_array

          # setting flag to check whether to refresh screen
          @group_idx = true
        else
          param_name = [vars[0], vars[1]].join('_')
          keys = ["provision_index", "scaling_max", "scaling_min", "start_action",
                  "start_delay", "stop_action", "stop_delay"]
          if keys.include?(param_name)
            @edit[:new][:rsc_groups].each_with_index do |groups, i|
              groups.sort_by { |gr| gr[:name].downcase }.each_with_index do |g, k|
                keys.each do |key|
                  param_key   = "#{key}_#{i}_#{k}".to_sym
                  param_value = params[param_key]
                  key         = key.to_sym

                  # convert start/stop delay into seconds, need to convert other values to_i
                  case key
                  when :start_delay, :stop_delay
                    g[key] = param_value.to_i * 60 if param_value
                  when :scaling_min
                    g[key] = param_value.to_i if param_value
                    # set flag to true so screen can be refreshed to adjust scaling_max pull down
                    g[:scaling_max] = g[:scaling_min] if g[:scaling_max] < g[:scaling_min]
                    @group_idx = true
                  when :scaling_max
                    g[key] = param_value.to_i if param_value
                  when :provision_index
                    if param_value
                      p_index = @edit[:new][:rsc_groups].flatten.collect { |r| r[:provision_index].to_i }.sort

                      # if index that came in is being used more than once
                      if p_index.count(g[key]) > 1
                        g[key] = param_value.to_i - 1
                      elsif p_index.count(g[key]) == 1
                        # if index being changed occur once
                        # rearrange all provision order values
                        rearrange_provision_order(@edit[:new][:rsc_groups], g[key])
                        if param_value.to_i > p_index.last
                          g[key] = p_index.last
                        else
                          g[key] = param_value.to_i - 1
                        end
                      end
                      # recalculate values for pull-down
                      @edit[:new][:provision_order] = recalculate_provision_order
                    end
                  else
                    g[key] = param_value if param_value
                  end
                end
              end
            end
          end
        end
      end
    end

    # recalculate available resources, if resource id selected
    get_available_resources("ServiceTemplate") if params[:resource_id]
    @in_a_form = true
  end

  # building/rebuilding provision order pull down
  # add one extra number in pull down
  def recalculate_provision_order
    order = @edit[:new][:rsc_groups].flatten.collect { |r| r[:provision_index].to_i }.sort.uniq
    order.empty? ? order.push(1) : order.push(order.last + 1)
  end

  # rearrange provision order values so numbers aren't skipped
  def rearrange_provision_order(resources, current_index_value)
    resources.flatten.collect do |group|
      group[:provision_index] -= 1 if group[:provision_index] > current_index_value
    end
  end

  # Get all info for the node about to be displayed
  def get_node_info(treenodeid)
    @nodetype, id = valid_active_node(treenodeid).split("_").last.split("-")
    # saving this so it can be used while adding buttons/groups in buttons editor
    @sb[:applies_to_id] = from_cid(id)
    tree_nodes = treenodeid.split('_')
    if tree_nodes.length >= 3 && tree_nodes[2].split('-').first == "xx"
      # buttons folder or nodes under that were clicked
      build_resolve_screen
      buttons_get_node_info(treenodeid)
    else
      @sb[:buttons_node] = false
      case TreeBuilder.get_model_for_prefix(@nodetype)
      when "Vm", "MiqTemplate", "ServiceResource"  # VM or Template record, show the record
        show_record(from_cid(id))
        @right_cell_text = _("%{model} \"%{name}\"") % {:name => @record.name, :model => ui_lookup(:model => TreeBuilder.get_model_for_prefix(@nodetype))}
      else      # Get list of child Catalog Items/Services of this node
        if x_node == "root"
          types = {
            :sandt_tree  => "ServiceTemplate",
            :svccat_tree => "Service",
            :stcat_tree  => "ServiceTemplateCatalog",
            :ot_tree     => "OrchestrationTemplate"
          }
          typ = types[x_active_tree]
          @no_checkboxes = true if x_active_tree == :svcs_tree
          if x_active_tree == :svccat_tree
            condition = ["display=? and service_template_catalog_id IS NOT NULL", true]
            service_template_list(condition, :no_checkboxes => true)
          else
            process_show_list(:model => typ.constantize)
          end
          @right_cell_text = _("All %{models}") % {:models => ui_lookup(:models => typ)}
        elsif ["xx-otcfn", "xx-othot", "xx-otazu"].include?(x_node)
          typ = node_name_to_template_name(x_node)
          @right_cell_text = _("All %{models}") % {:models => ui_lookup(:models => typ)}
          process_show_list(:model => typ.constantize, :gtl_dbname => :orchestrationtemplate)
        else
          if x_active_tree == :stcat_tree
            @record = ServiceTemplateCatalog.find_by_id(from_cid(id))
            @record_service_templates = rbac_filtered_objects(@record.service_templates)
            typ = x_active_tree == :svccat_tree ? "Service" : TreeBuilder.get_model_for_prefix(@nodetype)
            @right_cell_text = _("%{model} \"%{name}\"") % {:name => @record.name, :model => ui_lookup(:model => typ)}
          elsif x_active_tree == :ot_tree
            @record = OrchestrationTemplate.find_by_id(from_cid(id))
            @right_cell_text = _("%{model} \"%{name}\"") % {:name  => @record.name,
                                                            :model => ui_lookup(:model => @record.class.name)}
          else
            if id == "Unassigned" || @nodetype == "stc"
              model = x_active_tree == :svccat_tree ? "ServiceCatalog" : "ServiceTemplate"
              if id == "Unassigned"
                condition = ["service_template_catalog_id IS NULL"]
                service_template_list(condition, :model => model, :no_order_button => true)
                @right_cell_text = _("%{typ} in %{model} \"Unassigned\"") %
                                   {:typ   => ui_lookup(:models => "Service"),
                                    :model => ui_lookup(:model => "ServiceTemplateCatalog")}
              else
                condition = ["display=? and service_template_catalog_id=? and service_template_catalog_id IS NOT NULL", true, from_cid(id)]
                service_template_list(condition, :model => model, :no_order_button => true)
                stc = ServiceTemplateCatalog.find_by_id(from_cid(id))
                @right_cell_text = _("%{typ} in %{model} \"%{name}\"") % {:name => stc.name, :typ => ui_lookup(:models => "Service"), :model => ui_lookup(:model => "ServiceTemplateCatalog")}
              end
            else
              show_record(from_cid(id))
              if @record.atomic? && need_prov_dialogs?(@record.prov_type)
                @miq_request = MiqRequest.find_by_id(@record.service_resources[0].resource_id)
                prov_set_show_vars
              end
              @sb[:dialog_label]       = _("No Dialog")
              @sb[:fqname]             = nil
              @sb[:reconfigure_fqname] = nil
              @sb[:retire_fqname]      = nil
              @record.resource_actions.each do |ra|
                d = Dialog.where(:id => ra.dialog_id).first
                @sb[:dialog_label] = d.label if d
                case ra.action.downcase
                when 'provision'
                  @sb[:fqname] = ra.fqname
                when 'reconfigure'
                  @sb[:reconfigure_fqname] = ra.fqname
                when 'retirement'
                  @sb[:retire_fqname] = ra.fqname
                end
              end
              # saving values of ServiceTemplate catalog id and resource that are needed in view to build the link
              @sb[:stc_nodes] = {}
              @record.service_resources.each do |r|
                st = ServiceTemplate.find_by_id(r.resource_id)
                @sb[:stc_nodes][r.resource_id] = st.service_template_catalog_id ? st.service_template_catalog_id : "Unassigned" unless st.nil?
              end
              if params[:action] == "x_show"
                prefix = @record.service_template_catalog_id ? "stc-#{to_cid(@record.service_template_catalog_id)}" : "-Unassigned"
                self.x_node = "#{prefix}_#{params[:id]}"
              end
              typ = x_active_tree == :svccat_tree ? "Service" : TreeBuilder.get_model_for_prefix(@nodetype)
              @right_cell_text = _("%{model} \"%{name}\"") % {:name => @record.name, :model => ui_lookup(:model => typ)}
            end
          end
        end
      end
    end
    x_history_add_item(:id => treenodeid, :text => @right_cell_text)
  end

  def open_parent_nodes(record)
    existing_node = nil                      # Init var

    if record.kind_of?(OrchestrationTemplate)
      parents = [:id => template_to_node_name(record)]
    else
      # Check for parent nodes missing from vandt tree and return them if any
      parent_rec = ServiceTemplateCatalog.find_by_id(record.service_template_catalog_id)
      if parent_rec.nil?
        parents = [parent_rec, :id => "-Unassigned"]
      else
        parents = [parent_rec, :id => "stc-#{to_cid(record.service_template_catalog_id)}"]
      end
    end
    # Go up thru the parents and find the highest level unopened, mark all as opened along the way
    unless parents.empty? || # Skip if no parents or parent already open
           x_tree[:open_nodes].include?(parents.last[:id])
      parents.reverse_each do |p|
        unless p.nil?
          p_node = x_build_node_id(p, :full_ids => true)
          unless x_tree[:open_nodes].include?(p_node)
            x_tree[:open_nodes].push(p_node)
            existing_node = p_node
          end
        end
      end
    end
    add_nodes = {:key      => existing_node,
                 :children => TreeBuilder.tree_add_child_nodes(@sb,
                                                               x_tree[:klass_name],
                                                               existing_node)} if existing_node
    self.x_node = if params[:rec_id]
                    "stc-#{to_cid(record.service_template_catalog_id)}_st-#{to_cid(record.id)}"
                  elsif record.kind_of?(OrchestrationTemplate)
                    "xx-#{parents.last[:id]}_ot-#{to_cid(record.id)}"
                  else
                    "#{parents.last[:id]}_#{params[:id]}"
                  end
    add_nodes
  end

  # Replace the right cell of the explorer
  def replace_right_cell(action = nil, replace_trees = [])
    @explorer = true

    # FIXME: make this functional
    get_node_info(x_node) unless @tagging || @edit
    replace_trees   = @replace_trees   if @replace_trees    # get_node_info might set this
    right_cell_text = @right_cell_text if @right_cell_text  # get_node_info might set this too

    type, _id = x_node.split("_").last.split("-")
    trees = {}
    if replace_trees
      trees[:sandt]  = build_st_tree        if replace_trees.include?(:sandt)
      trees[:svccat] = build_svccat_tree    if replace_trees.include?(:svccat)
      trees[:stcat]  = build_stcat_tree     if replace_trees.include?(:stcat)
      trees[:ot]     = build_orch_tmpl_tree if replace_trees.include?(:ot)
    end
    allowed_records = %w(MiqTemplate OrchestrationTemplate Service ServiceTemplate ServiceTemplateCatalog)
    record_showing = (type && allowed_records.include?(TreeBuilder.get_model_for_prefix(type)) && !@view) ||
                     params[:action] == "x_show"
    # Clicked on right cell record, open the tree enough to show the node, if not already showing
    if params[:action] == "x_show" && x_active_tree != :stcat_tree &&
       @record && # Showing a record
       !@in_a_form                               # Not in a form
      add_nodes = open_parent_nodes(@record)      # Open the parent nodes of selected record, if not open
    end

    v_tb =
      case x_active_tree
      when :sandt_tree
        if record_showing && !@in_a_form
          if TreeBuilder.get_model_for_prefix(@nodetype) == "MiqTemplate"
            build_toolbar("summary_view_tb")
          end
        else
          build_toolbar("x_gtl_view_tb") if !%w(xx csb cbg cb).include?(@nodetype) && !@in_a_form
        end
      when :svccat_tree, :stcat_tree, :ot_tree
        build_toolbar("x_gtl_view_tb") unless record_showing || @in_a_form
      end

    unless @in_a_form
      c_tb = build_toolbar(center_toolbar_filename) unless x_active_tree == :svccat_tree
      h_tb = build_toolbar("x_history_tb")
    end

    presenter = ExplorerPresenter.new(
      :active_tree => x_active_tree,
      :add_nodes   => add_nodes
    )
    r = proc { |opts| render_to_string(opts) }
    replace_trees_by_presenter(presenter, trees)

    if @sb[:buttons_node]
      if action == "button_edit"
        right_cell_text = if @custom_button && @custom_button.id
                            _("Editing Button \"%{name}\"") % {:name => @custom_button.name}
                          else
                            _("Adding a new Button")
                          end
      elsif action == "group_edit"
        right_cell_text = if @custom_button_set && @custom_button_set.id
                            _("Editing Button Group \"%{name}\"") % {:name => @custom_button_set.name.split('|').first}
                          else
                            _("Adding a new Button Group")
                          end
      elsif action == "group_reorder"
        right_cell_text = _("Buttons Group Reorder")
      end
    end
    presenter[:right_cell_text] = right_cell_text

    # Replace right cell divs
    presenter.update(:main_div,
      if @tagging
        action_url = x_active_tree == :ot_tree ? "ot_tags_edit" : "st_tags_edit"
        r[:partial => "layouts/x_tagging", :locals => {:action_url => action_url}]
      elsif action && ["at_st_new", "st_new"].include?(action)
        r[:partial => "st_form"]
      elsif action && ["st_catalog_new", "st_catalog_edit"].include?(action)
        r[:partial => "stcat_form"]
      elsif action == "dialog_provision"
        r[:partial => "shared/dialogs/dialog_provision"]
      elsif %w(ot_add ot_copy ot_edit service_dialog_from_ot).include?(action)
        r[:partial => action]
      elsif record_showing
        if TreeBuilder.get_model_for_prefix(@nodetype) == "MiqTemplate"
          r[:partial => "vm_common/main", :locals => {:controller => "vm"}]
        elsif @sb[:buttons_node]
          r[:partial => "shared/buttons/ab_list"]
        else
          r[:partial => "catalog/#{x_active_tree}_show", :locals => {:controller => "catalog"}]
        end
      elsif @sb[:buttons_node]
        r[:partial => "shared/buttons/ab_list"]
      else
        presenter.update(:paging_div, r[:partial => "layouts/x_pagingcontrols"])
        r[:partial => "layouts/x_gtl"]
      end
    )

    presenter[:clear_gtl_list_grid] = @gtl_type && @gtl_type != 'list'

    # have to make Catalog Items accordion active incase link on Catalog show screen was pressed

    # Decide whether to show paging controls
    if @tagging
      presenter.hide(:toolbar).show(:paging_div)
      action_url = x_active_tree == :ot_tree ? "ot_tags_edit" : "st_tags_edit"
      locals = {
        :record_id           => @edit[:object_ids][0],
        :action_url          => action_url,
        :force_cancel_button => true,
        :ajax_buttons        => true
      }
      presenter.show(:form_buttons_div).hide(:pc_div_1)
      presenter.update(:form_buttons_div, r[:partial => "layouts/x_edit_buttons", :locals => locals])
    elsif record_showing || @in_a_form || @sb[:buttons_node] ||
          (@pages && (@items_per_page == ONE_MILLION || @pages[:items] == 0))
      if ['button_edit', 'group_edit', 'group_reorder', 'at_st_new',
          'st_new', 'st_catalog_new', 'st_catalog_edit'].include?(action)
        presenter.hide(:toolbar).show(:paging_div)
        # incase it was hidden for summary screen, and incase there were no records on show_list
        presenter.show(:form_buttons_div).hide(:pc_div_1)
        locals = {:record_id => @edit[:rec_id]}
        case action
        when 'group_edit'
          locals[:action_url] = @edit[:rec_id] ? 'group_update' : 'group_create'
        when 'group_reorder'
          locals[:action_url]   = 'ab_group_reorder'
          locals[:multi_record] = true
        when 'button_edit'
          locals[:action_url] = @edit[:rec_id] ? 'button_update' : 'button_create'
        when 'st_catalog_new', 'st_catalog_edit'
          locals[:action_url] = 'st_catalog_edit'
        else
          locals[:action_url] = 'servicetemplate_edit'
          locals[:serialize] = true
        end
        presenter.update(:form_buttons_div, r[:partial => "layouts/x_edit_buttons", :locals => locals])
      elsif action == "dialog_provision"
        presenter.hide(:toolbar)
        # incase it was hidden for summary screen, and incase there were no records on show_list
        presenter.show(:paging_div, :form_buttons_div).hide(:pc_div_1)
        @record.dialog_fields.each do |field|
          if ["DialogFieldDateControl", "DialogFieldDateTimeControl"].include?(field.type)
            presenter[:build_calendar] = {
              :date_from => field.show_past_dates ? nil : Time.zone.now,
            }
          end
        end
        presenter.update(:form_buttons_div, r[:partial => "layouts/x_dialog_buttons", :locals => {:action_url => "dialog_form_button_pressed", :record_id => @edit[:rec_id]}])
      elsif %w(ot_edit ot_copy ot_add service_dialog_from_ot).include?(action)
        presenter.hide(:toolbar).show(:paging_div, :form_buttons_div).hide(:pc_div_1)
        locals = {:record_id  => @edit[:rec_id],
                  :action_url => "#{action}_submit",
                  :serialize  => true}
        if action == "ot_copy"
          presenter.show(:buttons_on).hide(:buttons_off)
          locals[:record_id] = nil
        end
        locals[:no_reset] = true if %w(ot_copy service_dialog_from_ot).include?(action)
        presenter.update(:form_buttons_div, r[:partial => "layouts/x_edit_buttons", :locals => locals])
      else
        # Added so buttons can be turned off even tho div is not being displayed it still pops up Abandon changes box when trying to change a node on tree after saving a record
        presenter.hide(:buttons_on).show(:toolbar).hide(:paging_div)
      end
    else
      presenter.show(:form_buttons_div, :pc_div_1, :toolbar, :paging_div)
    end

    presenter.reload_toolbars(:history => h_tb, :center => c_tb, :view => v_tb)
    presenter.set_visibility(h_tb.present? || c_tb.present? || v_tb.present?, :toolbar)

    presenter[:record_id] = determine_record_id_for_presenter
    presenter[:lock_unlock_trees][x_active_tree] = @edit && @edit[:current]
    presenter[:osf_node] = x_node
    presenter.reset_changes
    presenter.reset_one_trans

    render :js => presenter.to_html
  end

  # Build a Catalog Items explorer tree
  def build_st_tree
    TreeBuilderCatalogItems.new('sandt_tree', 'sandt', @sb)
  end

  # Build a Services explorer tree
  def build_svccat_tree
    TreeBuilderServiceCatalog.new('svccat_tree', 'svccat', @sb)
  end

  # Build a Catalogs explorer tree
  def build_stcat_tree
    TreeBuilderCatalogs.new('stcat_tree', 'stcat', @sb)
  end

  # Build a Orchestration Templates explorer tree
  def build_orch_tmpl_tree
    TreeBuilderOrchestrationTemplates.new('ot_tree', 'ot', @sb)
  end

  def show_record(id = nil)
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype = "config"
    identify_catalog(id)

    return if record_no_longer_exists?(@record)
  end

  def get_session_data
    @title      = _("Catalog Items")
    @layout     = "catalogs"
    @lastaction = session[:svc_lastaction]
    @options    = session[:prov_options]
    @resolve    = session[:resolve] if session[:resolve]
  end

  def set_session_data
    session[:svc_lastaction] = @lastaction
    session[:prov_options]   = @options if @options
    session[:resolve]        = @resolve if @resolve
  end

  def dialog_catalog_check
    return unless @edit[:new][:display] && (@edit[:new][:dialog_id].nil? || @edit[:new][:dialog_id].to_i == 0)
    add_flash(_("Dialog has to be set if Display in Catalog is chosen"), :error)
  end
end
