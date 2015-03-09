# Setting Accordion methods included in OpsController.rb
module PxeController::PxeImageTypes
  extend ActiveSupport::Concern

  def pxe_image_type_tree_select
    typ, id = params[:id].split("_")
    case typ
    when "img"
      @record = session[:tree_selection] = MiqServer.find(from_cid(id))
    when "ps"
      @record = session[:tree_selection] = ServerRole.find(from_cid(id))
    end
  end

  def pxe_image_type_new
    assert_privileges("pxe_image_type_new")
    @pxe_image_type = PxeImageType.new
    pxe_image_type_set_form_vars
    @in_a_form = true
    replace_right_cell("pit")
  end

  def pxe_image_type_edit
    assert_privileges("pxe_image_type_edit")
    if params[:button] == "cancel"
      id = params[:id] || "new"
      return unless load_edit("pxe_image_type_edit__#{id}","replace_cell__explorer")
      if @edit[:pxe_id]
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"PxeImageType"), :name=>@edit[:current][:name]})
      else
        add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"PxeImageType"))
      end
      @edit = session[:edit] = nil # clean out the saved info
      get_node_info(x_node)
      replace_right_cell(x_node)
    elsif ["add","save"].include?(params[:button])
      id = params[:id] || "new"
      return unless load_edit("pxe_image_type_edit__#{id}","replace_cell__explorer")
      pxe_image_type_get_form_vars
      add_pxe = params[:id] ? find_by_id_filtered(PxeImageType, params[:id]) : PxeImageType.new
      pxe_image_type_validate_fields
      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end

      pxe_image_type_set_record_vars(add_pxe)

      if add_pxe.save
        AuditEvent.success(build_created_audit(add_pxe, @edit))
        @edit = session[:edit] = nil # clean out the saved info
        add_flash(_("%{model} \"%{name}\" was added") % {:model=>ui_lookup(:model=>"PxeImageType"), :name=>add_pxe.name})
        get_node_info(x_node)
        replace_right_cell(x_node, [:pxe_image_types, :customization_templates])
      else
        @in_a_form = true
        add_pxe.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    else
      #first time in or reset
      add_flash(_("All changes have been reset"), :warning) if params[:button] == "reset"
      unless params[:id]
        obj           = find_checked_items
        @_params[:id] = obj[0] unless obj.empty?
      end
      @pxe_image_type = @record = identify_record(params[:id], PxeImageType) if params[:id]
      pxe_image_type_set_form_vars
      @in_a_form = true
      session[:changed] = false
      replace_right_cell("pit")
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def pxe_image_type_form_field_changed
    return unless load_edit("pxe_image_type_edit__#{params[:id]}","replace_cell__explorer")
    pxe_image_type_get_form_vars
    render :update do |page|                    # Use JS to update the display
      page.replace_html("form_div", :partial=>"pxe_image_type_form") if params[:provision_type]
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  # Common VM button handler routines
  def pxe_image_type_button_operation(method, display_name)
    pxes = Array.new

    # Either a list or coming from a different controller (eg from host screen, go to its vms)
    if !params[:id]
      pxes = find_checked_items
      if pxes.empty?
        add_flash(_("No %{model} were selected to %{button}") % {:model=>ui_lookup(:models=>"PxeImageType"), :button=>display_name},
                  :error)
      else
        process_pxe_image_type(pxes, method)
      end

      get_node_info(x_node)
      replace_right_cell("root", [:pxe_image_types, :customization_templates])
    else # showing 1 vm
      if params[:id].nil? || PxeImageType.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:model=>"PxeImageType"),
                  :error)
        pxe_image_type_list
        @refresh_partial = "layouts/x_gtl"
      else
        pxes.push(params[:id])
        process_pxe_image_type(pxes, method)  unless pxes.empty?
        # TODO: tells callers to go back to show_list because this SMIS Agent may be gone
        # Should be refactored into calling show_list right here
        if method == 'destroy'
          self.x_node = "root"
          @single_delete = true unless flash_errors?
        end
        get_node_info(x_node)
        replace_right_cell(x_node, [:pxe_image_types, :customization_templates])
      end
    end
    return pxes.count
  end

  def pxe_image_type_delete
    assert_privileges("pxe_image_type_delete")
    pxe_image_type_button_operation('destroy', 'Delete')
  end

  def pxe_image_type_list
    @lastaction = "pxe_image_type_list"
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session[:pxe_image_type_sortcol].nil? ? 0 : session[:pxe_image_type_sortcol].to_i
    @sortdir = session[:pxe_image_type_sortdir].nil? ? "ASC" : session[:pxe_image_type_sortdir]

    @view, @pages = get_view(PxeImageType)  # Get the records (into a view) and the paginator

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session[:pxe_image_type_sortcol] = @sortcol
    session[:pxe_image_type_sortdir] = @sortdir

    if params[:action] != "button" && (params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page])
      render :update do |page|                    # Use RJS to update the display
        page.replace("gtl_div", :partial=>"layouts/x_gtl", :locals=>{:action_url=>"pxe_image_type_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  private #######################

  def pxe_image_type_validate_fields
    if @edit[:new][:name].blank?
      add_flash(_("%s is required") % "Name", :error)
    end
  end

  # Delete all selected or single displayed PXEImageType(s)
  def delete_pxe_image_types
    pxe_image_type_button_operation('destroy', 'deletion')
  end

  def pxe_image_type_set_record_vars(pxe)
    pxe.name = @edit[:new][:name]
    pxe.provision_type = @edit[:new][:provision_type]
  end

  # Get variables from edit form
  def pxe_image_type_get_form_vars
    @pxe_image_type = @edit[:pxe_id] ? PxeImageType.find_by_id(@edit[:pxe_id]) : PxeImageType.new
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:provision_type] = params[:provision_type] if params[:provision_type]
  end

  # Set form variables for edit
  def pxe_image_type_set_form_vars
    @edit = Hash.new
    @edit[:pxe_id] = @pxe_image_type.id
    @edit[:prov_types] = {:host=>ui_lookup(:model=>"host"),:vm=>ui_lookup(:model=>"vm")}
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "pxe_image_type_edit__#{@pxe_image_type.id || "new"}"
    @edit[:rec_id] = @pxe_image_type.id || nil

    @edit[:new][:name] = @pxe_image_type.name
    @edit[:new][:provision_type] = @pxe_image_type.provision_type
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  # Common Schedule button handler routines
  def process_pxe_image_type(pxes, task)
    process_elements(pxes, PxeImageType, task)
  end

  # Get information for an event
  def pxe_image_type_build_tree
    TreeBuilderPxeImageTypes.new("pxe_image_types_tree", "pxe_image_types", @sb)
  end

  def pxe_image_type_get_node_info(treenodeid)
    if treenodeid == "root"
      pxe_image_type_list
      @right_cell_text = _("All %s") % ui_lookup(:models => "PxeImageType")
      @right_cell_div  = "pxe_image_type_list"
    else
      @right_cell_div = "pxe_image_type_details"
      nodes = treenodeid.split("-")
      @record = @pxe_image_type = PxeImageType.find_by_id(from_cid(nodes.last))
      @right_cell_text = _("%{model} \"%{name}\"") % {:name=>@pxe_image_type.name, :model=>ui_lookup(:model=>"PxeImageType")}
    end
  end
end
