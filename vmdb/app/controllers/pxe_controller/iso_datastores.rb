# Setting Accordion methods included in OpsController.rb
module PxeController::IsoDatastores
  extend ActiveSupport::Concern

  def iso_datastore_tree_select
    typ, id = params[:id].split("_")
    case typ
    when "img"
      @record = session[:tree_selection] = MiqServer.find(from_cid(id))
    when "wimg"
      @record = session[:tree_selection] = WindowsImage.find(from_cid(id))
    when "ps"
      @record = session[:tree_selection] = ServerRole.find(from_cid(id))
    end
  end

  def iso_datastore_new
    assert_privileges("iso_datastore_new")
    @isd = IsoDatastore.new
    iso_datastore_set_form_vars
    @in_a_form = true
    replace_right_cell("isd")
  end

  def iso_datastore_edit
    unless params[:id]
      obj           = find_checked_items
      @_params[:id] = obj[0] unless obj.empty?
    end
    @isd = @record = identify_record(params[:id], IsoDatastore) if params[:id]
    iso_datastore_set_form_vars
    @in_a_form = true
    session[:changed] = false
    replace_right_cell("isd")
  end

  def iso_datastore_create
    id = params[:id] || "new"
    return unless load_edit("isd_edit__#{id}")
    iso_datastore_get_form_vars
    if params[:button] == "cancel"
      @edit = session[:edit] = nil # clean out the saved info
      add_flash(I18n.t("flash.add.cancelled",
                        :model=>ui_lookup(:model=>"IsoDatastore")))
      get_node_info(x_node)
      replace_right_cell(x_node)
    elsif params[:button] == "add"
      isd = params[:id] ? find_by_id_filtered(IsoDatastore, params[:id]) : IsoDatastore.new
      if @edit[:new][:ems_id].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"Provider"), :error)
      end
      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end
      iso_datastore_set_record_vars(isd)

      add_flash(I18n.t("flash.add.added",
                        :model=>ui_lookup(:model=>"IsoDatastore"),
                        :name=>@edit[:ems_name]))

      if !flash_errors? && isd.save!
        AuditEvent.success(build_created_audit(isd, @edit))
        @edit = session[:edit] = nil # clean out the saved info


        get_node_info(x_node)
        replace_right_cell(x_node,[:iso_datastores])
      else
        @in_a_form = true
        isd.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    elsif params[:button] == "reset"
      add_flash(_("All changes have been reset"), :warning)
      @in_a_form = true
      iso_datastore_edit
    end
  end


  # AJAX driven routine to check for changes in ANY field on the form
  def iso_datastore_form_field_changed
    return unless load_edit("isd_edit__#{params[:id]}","replace_cell__explorer")
    iso_datastore_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  # Refresh the power states for selected or single VMs
  def iso_datastore_refresh
    assert_privileges("iso_datastore_refresh")
    iso_datastore_button_operation('synchronize_advertised_images_queue', 'Refresh Relationships')
  end

  # Common VM button handler routines
  def iso_datastore_button_operation(method, display_name)
    isds = Array.new

    # Either a list or coming from a different controller (eg from host screen, go to its vms)
    if !params[:id]
      isds = find_checked_items
      if isds.empty?
        add_flash(I18n.t("flash.button.no_records_selected",
                        :model=>ui_lookup(:models=>"IsoDatastore"),
                        :button=>display_name),
                  :error)
      else
        process_iso_datastores(isds, method, display_name)
      end

      get_node_info(x_node)
      replace_right_cell(x_node,[:iso_datastores])
    else # showing 1 vm
      if params[:id].nil? || IsoDatastore.find_by_id(params[:id]).nil?
        add_flash(I18n.t("flash.button.record_gone",
                        :model=>ui_lookup(:model=>"IsoDatastore")),
                  :error)
        iso_datastore_list
        @refresh_partial = "layouts/x_gtl"
      else
        isds.push(params[:id])
        process_iso_datastores(isds, method, display_name)  unless isds.empty?
        # TODO: tells callers to go back to show_list because this iso_datastore may be gone
        # Should be refactored into calling show_list right here
        if method == 'destroy'
          self.x_node = "root"
          @single_delete = true unless flash_errors?
        end
        get_node_info(x_node)
        replace_right_cell(x_node,[:iso_datastores])
      end
    end
    return isds.count
  end

  def iso_datastore_delete
    assert_privileges("iso_datastore_delete")
    iso_datastore_button_operation('destroy', 'Delete')
  end

  def iso_datastore_list
    @lastaction = "iso_datastore_list"
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session[:iso_sortcol].nil? ? 0 : session[:iso_sortcol].to_i
    @sortdir = session[:iso_sortdir].nil? ? "ASC" : session[:iso_sortdir]

    @view, @pages = get_view(IsoDatastore)  # Get the records (into a view) and the paginator

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session[:iso_sortcol] = @sortcol
    session[:iso_sortdir] = @sortdir

    if params[:action] != "button" && (params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page])
      render :update do |page|                    # Use RJS to update the display
        page.replace("gtl_div", :partial=>"layouts/x_gtl", :locals=>{:action_url=>"iso_datastore_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  def iso_image_edit
    assert_privileges("iso_image_edit")
    case params[:button]
    when "cancel"
      add_flash(I18n.t("flash.edit.cancelled",
                      :model=>ui_lookup(:model=>"IsoImage"),
                      :name=>session[:edit][:img].name))
      @edit = session[:edit] = nil  # clean out the saved info
      get_node_info(x_node)
      replace_right_cell(x_node)
    when "save"
      return unless load_edit("iso_img_edit__#{params[:id]}","replace_cell__explorer")
      update_img = find_by_id_filtered(IsoImage, params[:id])
      iso_img_set_record_vars(update_img)
      if update_img.valid? && !flash_errors? && update_img.save!
        add_flash(I18n.t("flash.edit.saved",
                        :model=>ui_lookup(:model=>"IsoImage"),
                        :name=>update_img.name))
        AuditEvent.success(build_saved_audit(update_img, @edit))
        refresh_tree = @edit[:new][:default_for_windows] == @edit[:current][:default_for_windows] ? [] : [:iso_datastore]
        @edit = session[:edit] = nil  # clean out the saved info
        get_node_info(x_node)
        replace_right_cell(x_node, refresh_tree)
      else
        update_img.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        @in_a_form = true
        @changed = true
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end
    when "reset", nil
      @img = IsoImage.find_by_id(from_cid(params[:id]))
      iso_img_set_form_vars
      @in_a_form = true
      session[:changed] = false
      if params[:button] == "reset"
      add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("isi")
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def iso_img_form_field_changed
    return unless load_edit("iso_img_edit__#{params[:id]}","replace_cell__explorer")
    iso_img_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  private #######################

  # Get variables from edit form
  def iso_img_get_form_vars
    @img = @edit[:img]
    @edit[:new][:img_type] = params[:image_typ] if params[:image_typ]
    @edit[:new][:default_for_windows] = params[:default_for_windows] == "1" if params[:default_for_windows]
  end

  # Set form variables for edit
  def iso_img_set_form_vars
    @edit = Hash.new
    @edit[:img] = @img

    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "iso_img_edit__#{@img.id || "new"}"
    @edit[:rec_id] = @img.id || nil
    @edit[:pxe_image_types] = Array.new
    PxeImageType.all.sort{|a,b| a.name <=> b.name}.collect{|img| @edit[:pxe_image_types].push([img.name,img.id])}
    @edit[:new][:img_type] = @img.pxe_image_type ? @img.pxe_image_type.id : nil
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  def iso_img_set_record_vars(img)
    img.pxe_image_type = @edit[:new][:img_type].blank? ? nil : PxeImageType.find_by_id(@edit[:new][:img_type])
  end

  def identify_isd_datastore
    @isd = nil
    begin
      @record = @isd = find_by_id_filtered(IsoDatastore, from_cid(params[:id]))
    rescue ActiveRecord::RecordNotFound
    rescue StandardError => @bang
    end
  end

  # Delete all selected or single displayed ISO Datastore(s)
  def deleteisds
    iso_datastore_button_operation('destroy', 'deletion')
  end

  def iso_datastore_set_record_vars(isd)
    ems = EmsRedhat.find_by_id(@edit[:new][:ems_id])
    isd.ext_management_system = ems
    #saving name to use in flash message
    @edit[:ems_name] = ems.name
  end

  # Get variables from edit form
  def iso_datastore_get_form_vars
    @isd = @edit[:isd]
    @edit[:new][:ems_id] = params[:ems_id] if params[:ems_id]
  end

  # Set form variables for edit
  def iso_datastore_set_form_vars
    @edit = Hash.new
    @edit[:isd] = @isd

    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "isd_edit__#{@isd.id || "new"}"
    @edit[:rec_id] = @isd.id || nil
    @edit[:new][:ems_id] = @isd.ext_management_system ? @isd.ext_management_system.id : nil
    @edit[:emses] = Array.new
    EmsRedhat.find(:all).delete_if{|e| e.iso_datastore != nil}.sort{|a,b| a.name <=> b.name}.each do |ems|
      @edit[:emses].push([ems.name,ems.id])
    end

    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  # Common Schedule button handler routines
  def process_iso_datastores(elements, task, display_name)
    process_elements(elements, IsoDatastore, task, display_name, "ems_id")
  end

  # Get information for an event
  def iso_datastore_build_tree
    TreeBuilderIsoDatastores.new("iso_datastores_tree", "iso_datastores", @sb)
  end

  def iso_datastore_get_node_info(treenodeid)
    if treenodeid == "root"
      iso_datastore_list
      @right_cell_text = @right_cell_text = I18n.t("cell_header.all_model_records",
                                :model=>ui_lookup(:models=>"IsoDatastore"))
      @right_cell_div  = "iso_datastore_list"
    else
      @right_cell_div = "iso_datastore_details"
      nodes = treenodeid.split("-")
      if (nodes[0] == "isd" && nodes.length == 2) || (["isd_xx"].include?(nodes[1]) && nodes.length == 3)
        # on iso_datastore node OR folder node is selected
        @record = @isd = IsoDatastore.find_by_id(from_cid(nodes.last))
        @right_cell_text = I18n.t("cell_header.model_record",
                                  :name=>@isd.name,
                                  :model=>ui_lookup(:model=>"IsoDatastore"))
      elsif nodes[0] == "isi"
        @record = @img = IsoImage.find_by_id(from_cid(nodes.last))
        @right_cell_text = I18n.t("cell_header.model_record",
                                  :name=>@img.name,
                                  :model=>ui_lookup(:model=>"IsoImage"))
      end
    end
  end
end
