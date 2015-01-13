# Setting Accordion methods included in PxeController.rb
module PxeController::PxeCustomizationTemplates
  extend ActiveSupport::Concern

  # AJAX driven routine to check for changes in ANY field on the form
  def template_form_field_changed
    return unless load_edit("ct_edit__#{params[:id]}","replace_cell__explorer")
    @prev_typ = @edit[:new][:typ]
    template_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      if params[:typ] && @prev_typ != @edit[:new][:typ]
        @edit[:new][:script] = ""
        page.replace_html("script_div", :partial=>"template_script_data")
      end
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  def customization_template_delete
    assert_privileges("customization_template_delete")
    template_button_operation('destroy', 'Delete')
  end

  def template_list
    @lastaction = "template_list"
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session[:ct_sortcol].nil? ? 0 : session[:ct_sortcol].to_i
    @sortdir = session[:ct_sortdir].nil? ? "ASC" : session[:ct_sortdir]
    pxe_img_id = x_node.split('-').last == "system" ? nil : x_node.split('-').last
    if pxe_img_id
      @view, @pages = get_view(CustomizationTemplate,:conditions=>["pxe_image_type_id=?",from_cid(pxe_img_id)]) # Get the records (into a view) and the paginator
    else
      @view, @pages = get_view(CustomizationTemplate,:conditions=>["system=?",true])  # Get the records (into a view) and the paginator
    end

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session[:ct_sortcol] = @sortcol
    session[:ct_sortdir] = @sortdir

    if params[:action] != "button" && (params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page])
      render :update do |page|                    # Use RJS to update the display
        page.replace("gtl_div", :partial=>"layouts/x_gtl", :locals=>{:action_url=>"template_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  def customization_template_new
    assert_privileges("customization_template_new")
    @ct = CustomizationTemplate.new
    template_set_form_vars
    @in_a_form = true
    replace_right_cell("ct-")
  end

  def customization_template_copy
    assert_privileges("customization_template_copy")
    @_params[:typ] = "copy"
    customization_template_edit
  end

  def customization_template_edit
    assert_privileges("customization_template_edit")
    unless params[:id]
      obj = find_checked_items
      @_params[:id] = obj[0] unless obj.empty?
    end
    @ct = @record = identify_record(params[:id], CustomizationTemplate) if params[:id]
    if params[:typ] && params[:typ] == "copy"
      options = Hash.new
      options[:name] = "Copy of #{@record.name}"
      options[:description] = @record.description
      options[:script] = @record.script
      options[:type] = @record.type
      options[:pxe_image_type_id] = @record.pxe_image_type_id.to_s if @record.pxe_image_type_id
      @ct = CustomizationTemplate.new(options)
    end
    template_set_form_vars
    @in_a_form = true
    session[:changed] = false
    replace_right_cell("ct-#{params[:id]}")
  end

  def template_create_update
    id = params[:id] || "new"
    return unless load_edit("ct_edit__#{id}")
    template_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    if params[:button] == "cancel"
      @edit = session[:edit] = nil # clean out the saved info
      @ct.id ? add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"PxeCustomizationTemplate"), :name=>@ct.name}) :
              add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"PxeCustomizationTemplate"))
      get_node_info(x_node)
      replace_right_cell(x_node)
    elsif ["add","save"].include?(params[:button])
      if params[:id]
        ct = find_by_id_filtered(CustomizationTemplate, params[:id])
      else
        ct = @edit[:new][:typ] == "CustomizationTemplateKickstart" ?
            CustomizationTemplateKickstart.new : CustomizationTemplateSysprep.new
      end
      if @edit[:new][:name].blank?
        add_flash(_("%s is required") % "Name", :error)
      end
      if @edit[:new][:typ].blank?
        add_flash(_("%s is required") % "Type", :error)
      end
      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end

      template_set_record_vars(ct)

      if !flash_errors? && ct.valid? && ct.save
        flash_key = ct_id ? _("%{model} \"%{name}\" was saved") : _("%{model} \"%{name}\" was added")
        add_flash(flash_key % {:model => ui_lookup(:model => "PxeCustomizationTemplate"), :name  => ct.name})
          AuditEvent.success(build_created_audit(ct, @edit))
          @edit = session[:edit] = nil # clean out the saved info
          self.x_node = "xx-xx-#{to_cid(ct.pxe_image_type.id)}"
          get_node_info(x_node)
          replace_right_cell(x_node,[:customization_templates])
      else
        @in_a_form = true
        ct.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    elsif params[:button] == "reset"
      add_flash(_("All changes have been reset"), :warning)
      @in_a_form = true
      customization_template_edit
    end
  end

  private #######################

  # Delete all selected or single displayed PXE Server(s)
  def deletetemplates
    template_button_operation('destroy', 'deletion')
  end

  # Get variables from edit form
  def template_get_form_vars
    @ct = @edit[:ct_id] ? CustomizationTemplate.find_by_id(@edit[:ct_id]) : CustomizationTemplate.new
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:img_type] = params[:img_typ] if params[:img_typ]
    @edit[:new][:typ] = params[:typ] if params[:typ]
    @edit[:new][:script] = params[:script_data] if params[:script_data]
    @edit[:new][:script] = @edit[:new][:script] + "..." if !params[:name] && !params[:description] && !params[:img_typ] && !params[:script_data] && !params[:typ]
  end

  # Set form variables for edit
  def template_set_form_vars
    @edit = Hash.new
    @edit[:ct_id] = @ct.id

    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "ct_edit__#{@ct.id || "new"}"
    @edit[:rec_id] = @ct.id || nil
    @edit[:pxe_image_types] = Array.new
    PxeImageType.all.sort{|a,b| a.name <=> b.name}.collect{|img| @edit[:pxe_image_types].push([img.name,img.id])}
    @edit[:new][:name] = @ct.name
    @edit[:new][:description] = @ct.description
    @edit[:new][:typ] = @ct.type
    #in case record is being copied
    if @ct.id || @ct.pxe_image_type_id
      @edit[:new][:img_type] = @ct.pxe_image_type.id
    else
      #if new customization template, check if add button was pressed form folder level, to auto select image type
      @edit[:new][:img_type] = x_node == "T" ? @ct.pxe_image_type : x_node.split('_')[1]
    end

    @edit[:new][:script] = @ct.script || ""
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  def template_set_record_vars(ct)
    ct.name = @edit[:new][:name]
    ct.description = @edit[:new][:description]
    ct.type = @edit[:new][:typ]
    ct.pxe_image_type = PxeImageType.find_by_id(@edit[:new][:img_type])
    ct.script = @edit[:new][:script]
  end

  # Common Schedule button handler routines
  def process_templates(templates, task)
    process_elements(templates, CustomizationTemplate, task)
  end

  # Common template button handler routines
  def template_button_operation(method, display_name)
    templates = Array.new

    # Either a list or coming from a different controller (eg from host screen, go to its vms)
    if !params[:id]
      templates = find_checked_items
      if templates.empty?
        add_flash(_("No %{model} were selected to %{button}") % {:model=>ui_lookup(:models=>"PxeCustomizationTemplate"), :button=>display_name},
                  :error)
      else
        process_templates(templates, method)
      end

      get_node_info(x_node)
      replace_right_cell(x_node,[:customization_templates])
    else # showing 1 vm
      if params[:id].nil? || CustomizationTemplate.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:model=>"PxeCustomizationTemplate"),
                  :error)
        template_list
        @refresh_partial = "layouts/gtl"
      else
        templates.push(params[:id])
        ct = CustomizationTemplate.find_by_id(from_cid(params[:id]))  if method == 'destroy'        #need to set this for destroy method so active node can be set to image_type folder node after record is deleted
        process_templates(templates, method)  unless templates.empty?
        # TODO: tells callers to go back to show_list because this SMIS Agent may be gone
        # Should be refactored into calling show_list right here
        if method == 'destroy'
          self.x_node = "xx-xx-#{to_cid(ct.pxe_image_type_id)}"
        end
        get_node_info(x_node)
        replace_right_cell(x_node,[:customization_templates])
      end
    end
    return templates.count
  end

  def template_get_node_info(treenodeid)
    if treenodeid == "root"
      @folders = PxeImageType.all.sort
      #to check if Add customization template button should be enabled
      @temp[:pxe_image_types_count] = @folders.count
      @right_cell_text = _("All %{model} - %{group}") % {:model=>ui_lookup(:models=>"PxeCustomizationTemplate"), :group=>ui_lookup(:models=>"PxeImageType")}
      @right_cell_div  = "template_list"
    else
      nodes = treenodeid.split("-")
      if nodes[0] == "ct"
        @right_cell_div = "template_details"
        @record = @ct = CustomizationTemplate.find_by_id(from_cid(nodes[1]))
        @right_cell_text = _("%{model} \"%{name}\"") % {:name=>@ct.name, :model=>ui_lookup(:model=>"PxeCustomizationTemplate")}
      else
        template_list
        @temp[:pxe_image_types_count] = PxeImageType.count
        pxe_img_id = x_node.split('-').last

        pxe_img_type = PxeImageType.find_by_id(from_cid(pxe_img_id)) if pxe_img_id != "system"
        @right_cell_text = pxe_img_id == "system" ? _("%s") % "Examples (read only)" :
                                    _("%{model} for %{group} \"%{name}\"") % {:name=>pxe_img_type.name, :model=>ui_lookup(:models=>"PxeCustomizationTemplate"), :group=>ui_lookup(:model=>"PxeImageType")}
        @right_cell_div  = "template_list"
      end
    end
  end

  # Get information for an event
  def customization_template_build_tree
    TreeBuilderPxeCustomizationTemplates.new("customization_templates_tree", "customization_templates", @sb)
  end
end
