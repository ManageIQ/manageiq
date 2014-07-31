module MiqAeCustomizationController::OldDialogs
  extend ActiveSupport::Concern

  # Delete all selected or single displayed PXE Server(s)
  def deletedialogs
    old_dialogs_button_operation('destroy', 'deletion')
  end

  # Get variables from edit form
  def old_dialogs_get_form_vars
    @dialog = @edit[:dialog]
    @edit[:new][:name] = CGI::unescape(params[:name]) if params[:name]
    @edit[:new][:description] = CGI::unescape(params[:description]) if params[:description]
    @edit[:new][:dialog_type] = CGI::unescape(params[:dialog_type]) if params[:dialog_type]
    @edit[:new][:content] = params[:content_data] if params[:content_data]
    @edit[:new][:content] = @edit[:new][:content] + "..." if !params[:name] && !params[:description] && !params[:dialog_type] && !params[:content_data]
  end

  # Set form variables for edit
  def old_dialogs_set_form_vars
    @edit = Hash.new
    @edit[:dialog] = @dialog

    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "dialog_edit__#{@dialog.id || "new"}"

    @edit[:new][:name] = @dialog.name
    @edit[:new][:description] = @dialog.description
    if @dialog.dialog_type
      @edit[:new][:dialog_type] = @dialog.dialog_type
    else
      #if new customization dialogs, check if add button was pressed form folder level, to auto select image type
      @edit[:new][:dialog_type] = x_node == "root" ? @dialog.dialog_type : x_node.split('_')[1]
    end

    @edit[:new][:content] = @dialog.content.to_yaml
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  def old_dialogs_set_record_vars(dialog)
    dialog.name = @edit[:new][:name]
    dialog.description = @edit[:new][:description]
    dialog.dialog_type = @edit[:new][:dialog_type]
    dialog.content = YAML.load(@edit[:new][:content])
  end

  # Common Schedule button handler routines
  def process_old_dialogs(dialogs, task)
    process_elements(dialogs, MiqDialog, task)
  end

  # Common VM button handler routines
  def old_dialogs_button_operation(method, display_name)
    dialogs = Array.new

    # Either a list or coming from a different controller (eg from host screen, go to its vms)
    if !params[:id]
      dialogs = find_checked_items
      if dialogs.empty?
        add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:model=>"MiqDialog"), :task=>display_name), :error)
      else
        to_delete = Array.new
        dialogs.each do |d|
          dialog = MiqDialog.find(d)
          if dialog.default == true
            to_delete.push(d)
            add_flash(I18n.t("flash.cant_delete_default", :model=>ui_lookup(:model=>"MiqDialog"), :name=>dialog.name), :error)
          end
        end
        #deleting elements in temporary array, had to create temp array to hold id's to be deleted from dialogs array, .each gets confused if i deleted them in above loop
        to_delete.each do |a|
          dialogs.delete(a)
        end
        process_old_dialogs(dialogs, method)
      end

      get_node_info
      replace_right_cell(x_node,[:old_dialogs])
    else # showing 1 vm
      if params[:id].nil? || MiqDialog.find_by_id(params[:id]).nil?
        add_flash(I18n.t("flash.record.no_longer_exists", :model=>ui_lookup(:model=>"MiqDialog")), :error)
        old_dialogs_list
        @refresh_partial = "layouts/gtl"
      else
        dialogs.push(params[:id])
        dialog = MiqDialog.find_by_id(from_cid(params[:id]))  if method == 'destroy'        #need to set this for destroy method so active node can be set to image_type folder node after record is deleted
        process_old_dialogs(dialogs, method)  unless dialogs.empty?
        # TODO: tells callers to go back to show_list because this SMIS Agent may be gone
        # Should be refactored into calling show_list right here
        if method == 'destroy'
          self.x_node = "xx-MiqDialog_#{dialog.dialog_type}"
        end
        get_node_info
        replace_right_cell(x_node,[:old_dialogs])
      end
    end
    return dialogs.count
  end

  def old_dialogs_get_node_info(treenodeid)
    if treenodeid == "root"
      @folders = MiqDialog::DIALOG_TYPES.sort
      @right_cell_text = I18n.t("cell_header.all_model_records",
                                :model=>ui_lookup(:models=>"MiqDialog"))
      @right_cell_div  = "old_dialogs_list"
    else
      nodes = treenodeid.split("_")
      if nodes[0].split('-').first == "odg"
        @right_cell_div = "dialogs_details"
        @record = @dialog = MiqDialog.find_by_id(from_cid(nodes[0].split('-').last))
        @right_cell_text = I18n.t("cell_header.model_record",
                                :model=>ui_lookup(:models=>"MiqDialog"),
                                :name=>@dialog.description)
      else
        old_dialogs_list
        img_typ = ""
        MiqDialog::DIALOG_TYPES.each do |typ|
          img_typ = typ[0] if typ[1] == nodes[1]
        end
        @right_cell_text = I18n.t("cell_header.type_of_model_records",
                                :typ=>img_typ,
                                :model=>ui_lookup(:models=>"MiqDialog"))
        @right_cell_div  = "old_dialogs_list"
      end
    end
  end


  # AJAX driven routine to check for changes in ANY field on the form
  def old_dialogs_form_field_changed
    return unless load_edit("dialog_edit__#{params[:id]}","replace_cell__explorer")
    old_dialogs_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  def old_dialogs_delete
    assert_privileges("old_dialogs_delete")
    old_dialogs_button_operation('destroy', 'Delete')
  end

  def old_dialogs_list
    @lastaction = "old_dialogs_list"
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session[:dialog_sortcol].nil? ? 0 : session[:dialog_sortcol].to_i
    @sortdir = session[:dialog_sortdir].nil? ? "ASC" : session[:dialog_sortdir]

    @view, @pages = get_view(MiqDialog,:conditions=>["dialog_type=?",x_node.split('_').last]) # Get the records (into a view) and the paginator

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session[:dialog_sortcol] = @sortcol
    session[:dialog_sortdir] = @sortdir

    if params[:ppsetting] || params[:searchtag] || params[:entry] ||
      params[:sort_choice] || params[:page]
      render :update do |page|
        page.replace("gtl_div",
                     :partial => "layouts/x_gtl",
                     :locals  => {:action_url => "old_dialogs_list",
                                  :button_div => 'policy_bar'})
        page.replace_html("paging_div", :partial => "layouts/x_pagingcontrols")
        page << "miqSparkle(false)"
      end
    end
  end

  def old_dialogs_new
    assert_privileges("old_dialogs_new")
    @dialog = MiqDialog.new
    old_dialogs_set_form_vars
    @in_a_form = true
    replace_right_cell("odg-")
  end

  def old_dialogs_copy
    assert_privileges("old_dialogs_copy")
    @_params[:typ] = "copy"
    old_dialogs_edit
  end

  def old_dialogs_edit
    assert_privileges("old_dialogs_edit")
    unless params[:id]
      obj = find_checked_items
      @_params[:id] = obj[0] unless obj.empty?
    end

    if params[:typ] == "copy"
      dialog = MiqDialog.find_by_id(from_cid(params[:id]))
      @dialog = MiqDialog.new
      @dialog.name = "Copy of " + dialog.name
      @dialog.description = dialog.description
      @dialog.dialog_type = dialog.dialog_type
      @dialog.content = dialog.content
      session[:changed] = true
    else
      @dialog = @record = identify_record(params[:id], MiqDialog) if params[:id]
      session[:changed] = false
    end
    if @dialog.default == true
      add_flash(I18n.t("flash.cant_edit_default", :model=>ui_lookup(:model=>"MiqDialog"), :name=>@dialog.name), :error)
      get_node_info
      replace_right_cell(x_node)
      return
    end
    old_dialogs_set_form_vars
    @in_a_form = true
    replace_right_cell("odg-#{params[:id]}")
  end

  def old_dialogs_create
    return unless load_edit("dialog_edit__new")
    old_dialogs_update_create
  end

  def old_dialogs_update
    id = params[:id] ? params[:id] : "new"
    return unless load_edit("dialog_edit__#{id}","replace_cell__explorer")
    old_dialogs_update_create
  end

  private

  def old_dialogs_update_create
    old_dialogs_get_form_vars
    case params[:button]
    when "cancel"
      @edit = session[:edit] = nil # clean out the saved info
      if !@dialog || @dialog.id.blank?
        add_flash(I18n.t("flash.add.cancelled", :model=>ui_lookup(:model=>"MiqDialog")))
      else
        add_flash(I18n.t("flash.edit.cancelled", :model=>ui_lookup(:model=>"MiqDialog"), :name=>@dialog.name))
      end
      get_node_info
      replace_right_cell(x_node)
    when "add","save"
      #dialog = find_by_id_filtered(MiqDialog, params[:id])
      dialog = @dialog.id.blank? ? MiqDialog.new : MiqDialog.find(@dialog.id) # Get new or existing record
      if @edit[:new][:name].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error)
      end
      if !@edit[:new][:dialog_type]
        add_flash(I18n.t("flash.edit.select_required", :selection=>"Dialog Type"), :error)
      end
      begin
        YAML.parse(@edit[:new][:content])
      rescue YAML::SyntaxError => ex
        add_flash("#{I18n.t("flash.edit.field_syntax_error.yaml")}#{ex.message}", :error)
      end
      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end

      old_dialogs_set_record_vars(dialog)
      begin
        dialog.save!
      rescue Exception => err
        dialog.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        @changed = true
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      else
        if params[:button] == "add"
          add_flash(I18n.t("flash.add.added", :model=>ui_lookup(:model=>"MiqDialog"), :name=>dialog.name))
        else
          add_flash(I18n.t("flash.edit.saved", :model=>ui_lookup(:model=>"MiqDialog"), :name=>dialog.name))
        end
        AuditEvent.success(build_saved_audit(dialog, @edit))
        @edit = session[:edit] = nil  # clean out the saved info
        #if editing from list view then change active_node to be same as updated image_type folder node
        if x_node.split('-')[0] == "xx"
          self.x_node = "xx-MiqDialog_#{dialog.dialog_type}"
        else
          if params[:button] == "add"
            d = MiqDialog.find_by_name_and_dialog_type(dialog.name,dialog.dialog_type)
            self.x_node = "odg-#{to_cid(d.id)}"
          end
        end
        get_node_info
        replace_right_cell(x_node,[:old_dialogs])
      end
    when "reset", nil	# Reset or first time in
      add_flash(I18n.t("flash.edit.reset"), :warning)
      @in_a_form = true
      old_dialogs_edit
    end
  end

end
