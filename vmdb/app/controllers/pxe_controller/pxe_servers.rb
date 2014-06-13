# Setting Accordion methods included in OpsController.rb
module PxeController::PxeServers
  extend ActiveSupport::Concern

  def pxe_server_tree_select
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

  def pxe_server_new
    assert_privileges("pxe_server_new")
    @ps = PxeServer.new
    pxe_server_set_form_vars
    @in_a_form = true
    replace_right_cell("ps")
  end

  def pxe_server_edit
    assert_privileges("pxe_server_edit")
    unless params[:id]
      obj           = find_checked_items
      @_params[:id] = obj[0] unless obj.empty?
    end
    @ps = @record = identify_record(params[:id], PxeServer) if params[:id]
    pxe_server_set_form_vars
    @in_a_form = true
    session[:changed] = false
    replace_right_cell("ps")
  end

  def pxe_server_create_update
    id = params[:id] || "new"
    return unless load_edit("pxe_edit__#{id}")
    pxe_server_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    if params[:button] == "cancel"
      @edit = session[:edit] = nil # clean out the saved info
      if @ps && @ps.id
        add_flash(I18n.t("flash.edit.cancelled",
                         :model=>ui_lookup(:model=>"PxeServer"),
                         :name=>@ps.name))
      else
        add_flash(I18n.t("flash.add.cancelled",
                         :model=>ui_lookup(:model=>"PxeServer")))
      end
      get_node_info(x_node)
      replace_right_cell(x_node)
    elsif ["add","save"].include?(params[:button])
      pxe = params[:id] ? find_by_id_filtered(PxeServer, params[:id]) : PxeServer.new
      pxe_server_validate_fields
      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end

      #only verify_depot_hash if anything has changed in depot settings
      if @edit[:new][:uri_prefix] != @edit[:current][:uri_prefix] || @edit[:new][:uri] != @edit[:current][:uri] ||
          @edit[:new][:log_userid] != @edit[:current][:log_userid] || @edit[:new][:log_password] != @edit[:current][:log_password]
        pxe_server_set_record_vars(pxe)
      end

      add_flash(I18n.t(pxe.id ? "flash.edit.saved" : "flash.add.added",
                         :model=>ui_lookup(:model=>"PxeServer"),
                         :name=>@edit[:new][:name]))

      if pxe.valid? && !flash_errors? && pxe_server_set_record_vars(pxe) && pxe.save!
        AuditEvent.success(build_created_audit(pxe, @edit))
        @edit = session[:edit] = nil # clean out the saved info


        get_node_info(x_node)
        replace_right_cell(x_node,[:pxe_servers])
      else
        @in_a_form = true
        pxe.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    elsif params[:button] == "reset"
      add_flash(I18n.t("flash.edit.reset"), :warning)
      @in_a_form = true
      pxe_server_edit
    end
  end


  # AJAX driven routine to check for changes in ANY field on the form
  def pxe_server_form_field_changed
    return unless load_edit("pxe_edit__#{params[:id]}","replace_cell__explorer")
    @edit[:prev_protocol] = @edit[:new][:protocol]
    pxe_server_get_form_vars
    log_depot_set_verify_status
    render :update do |page|                    # Use JS to update the display
      page.replace("form_div", :partial=>"pxe_form") if @edit[:new][:protocol] != @edit[:prev_protocol]
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
      if @edit[:log_verify_status] != session[:log_depot_log_verify_status]
        session[:log_depot_log_verify_status] = @edit[:log_verify_status]
        if @edit[:log_verify_status]
          page << "miqValidateButtons('show', 'log_');"
        else
          page << "miqValidateButtons('hide', 'log_');"
        end
      end
    end
  end

  # Refresh the power states for selected or single VMs
  def pxe_server_refresh
    assert_privileges("pxe_server_refresh")
    #pxe_button_operation('sync_images_queue', 'Refresh Relationships')
    pxe_button_operation('synchronize_advertised_images_queue', 'Refresh Relationships')
  end

  # Common VM button handler routines
  def pxe_button_operation(method, display_name)
    pxes = Array.new

    # Either a list or coming from a different controller (eg from host screen, go to its vms)
    if !params[:id]
      pxes = find_checked_items
      if pxes.empty?
        add_flash(I18n.t("flash.button.no_records_selected",
                        :model=>ui_lookup(:models=>"PxeServer"),
                        :button=>display_name),
                  :error)
      else
        process_pxes(pxes, method, display_name)
      end

      get_node_info(x_node)
      replace_right_cell(x_node,[:pxe_servers])
    else # showing 1 vm
      if params[:id].nil? || PxeServer.find_by_id(params[:id]).nil?
        add_flash(I18n.t("flash.button.record_gone",
                        :model=>ui_lookup(:model=>"PxeServer")),
                  :error)
        pxe_server_list
        @refresh_partial = "layouts/x_gtl"
      else
        pxes.push(params[:id])
        process_pxes(pxes, method, display_name)  unless pxes.empty?
        # TODO: tells callers to go back to show_list because this SMIS Agent may be gone
        # Should be refactored into calling show_list right here
        if method == 'destroy'
          self.x_node = "root"
          @single_delete = true unless flash_errors?
        end
        get_node_info(x_node)
        replace_right_cell(x_node,[:pxe_servers])
      end
    end
    return pxes.count
  end

  def pxe_server_delete
    assert_privileges("pxe_server_delete")
    pxe_button_operation('destroy', 'Delete')
  end

  def pxe_server_list
    @lastaction = "pxe_server_list"
    @force_no_grid_xml   = true
    @gtl_type            = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session[:pxe_sortcol].nil? ? 0 : session[:pxe_sortcol].to_i
    @sortdir = session[:pxe_sortdir].nil? ? "ASC" : session[:pxe_sortdir]

    @view, @pages = get_view(PxeServer) # Get the records (into a view) and the paginator

    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    session[:pxe_sortcol] = @sortcol
    session[:pxe_sortdir] = @sortdir

    if params[:action] != "button" && (params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page])
      render :update do |page|                    # Use RJS to update the display
        page.replace("gtl_div", :partial=>"layouts/x_gtl", :locals=>{:action_url=>"pxe_server_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  def pxe_image_edit
    assert_privileges("pxe_image_edit")
    case params[:button]
    when "cancel"
      add_flash(I18n.t("flash.edit.cancelled",
                      :model=>ui_lookup(:model=>"PxeImage"),
                      :name=>session[:edit][:img].name))
      @edit = session[:edit] = nil  # clean out the saved info
      get_node_info(x_node)
      replace_right_cell(x_node)
    when "save"
      return unless load_edit("pxe_img_edit__#{params[:id]}","replace_cell__explorer")
      update_img = find_by_id_filtered(PxeImage, params[:id])
      pxe_img_set_record_vars(update_img)
      if update_img.valid? && !flash_errors? && update_img.save!
        add_flash(I18n.t("flash.edit.saved",
                        :model=>ui_lookup(:model=>"PxeImage"),
                        :name=>update_img.name))
        AuditEvent.success(build_saved_audit(update_img, @edit))
        refresh_trees = @edit[:new][:default_for_windows] == @edit[:current][:default_for_windows] ? [] : [:pxe_server]
        @edit = session[:edit] = nil  # clean out the saved info
        get_node_info(x_node)
        replace_right_cell(x_node, refresh_trees)
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
      @img = PxeImage.find_by_id(from_cid(params[:id]))
      pxe_img_set_form_vars
      @in_a_form = true
      session[:changed] = false
      if params[:button] == "reset"
      add_flash(I18n.t("flash.edit.reset"), :warning)
      end
      replace_right_cell("pi")
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def pxe_img_form_field_changed
    return unless load_edit("pxe_img_edit__#{params[:id]}","replace_cell__explorer")
    pxe_img_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  def pxe_wimg_edit
    assert_privileges("pxe_wimg_edit")
    case params[:button]
      when "cancel"
        add_flash(I18n.t("flash.edit.cancelled",
                         :model=>ui_lookup(:model=>"WindowsImage"),
                         :name=>session[:edit][:wimg].name))
        @edit = session[:edit] = nil  # clean out the saved info
        get_node_info(x_node)
        replace_right_cell(x_node)
      when "save"
        return unless load_edit("pxe_wimg_edit__#{params[:id]}","replace_cell__explorer")
        update_wimg = find_by_id_filtered(WindowsImage, params[:id])
        pxe_wimg_set_record_vars(update_wimg)
        if update_wimg.valid? && !flash_errors? && update_wimg.save!
          add_flash(I18n.t("flash.edit.saved",
                           :model=>ui_lookup(:model=>"WindowsImage"),
                           :name=>update_wimg.name))
          AuditEvent.success(build_saved_audit(update_wimg, @edit))
          @edit = session[:edit] = nil  # clean out the saved info
          get_node_info(x_node)
          replace_right_cell(x_node)
        else
          update_wimg.errors.each do |field,msg|
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
        @wimg = WindowsImage.find_by_id(from_cid(params[:id]))
        pxe_wimg_set_form_vars
        @in_a_form = true
        session[:changed] = false
        if params[:button] == "reset"
          add_flash(I18n.t("flash.edit.reset"), :warning)
        end
        replace_right_cell("wi")
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def pxe_wimg_form_field_changed
    return unless load_edit("pxe_wimg_edit__#{params[:id]}","replace_cell__explorer")
    pxe_wimg_get_form_vars
    render :update do |page|                    # Use JS to update the display
      changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  private #######################

  def pxe_server_validate_fields
    if @edit[:new][:name].blank?
      add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error)
    end
    if @edit[:new][:uri_prefix].blank?
      add_flash(I18n.t("flash.edit.field_required", :field=>"Depot Type"), :error)
    end
    if @edit[:new][:uri_prefix] == "nfs" && @edit[:new][:uri].blank?
      add_flash(I18n.t("flash.edit.field_required", :field=>"URI"), :error)
    end
    if @edit[:new][:uri_prefix] == "smb" || @edit[:new][:uri_prefix] == "ftp"
      if @edit[:new][:uri].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"URI"), :error)
      end
      if @edit[:new][:log_userid].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"User ID"), :error)
      end
      if @edit[:new][:log_password].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"Password"), :error)
      elsif @edit[:new][:log_password] != @edit[:new][:log_verify]
        add_flash(I18n.t("flash.edit.passwords_mismatch"), :error)
      end
    end
  end

  # Get variables from edit form
  def pxe_img_get_form_vars
    @img = @edit[:img]
    @edit[:new][:img_type] = params[:image_typ] if params[:image_typ]
    @edit[:new][:default_for_windows] = params[:default_for_windows] == "1" if params[:default_for_windows]
  end

  # Set form variables for edit
  def pxe_img_set_form_vars
    @edit = Hash.new
    @edit[:img] = @img

    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "pxe_img_edit__#{@img.id || "new"}"
    @edit[:rec_id] = @img.id || nil
    @edit[:pxe_image_types] = Array.new
    PxeImageType.all.sort{|a,b| a.name <=> b.name}.collect{|img| @edit[:pxe_image_types].push([img.name,img.id])}
    @edit[:new][:img_type] = @img.pxe_image_type ? @img.pxe_image_type.id : nil
    @edit[:new][:default_for_windows] = @img.default_for_windows

    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  def pxe_img_set_record_vars(img)
    img.pxe_image_type = @edit[:new][:img_type].blank? ? nil : PxeImageType.find_by_id(@edit[:new][:img_type])
    img.default_for_windows = @edit[:new][:default_for_windows]
  end

  # Get variables from edit form
  def pxe_wimg_get_form_vars
    @wimg = @edit[:wimg]
    @edit[:new][:img_type] = params[:image_typ] if params[:image_typ]
  end

  # Set form variables for edit
  def pxe_wimg_set_form_vars
    @edit = Hash.new
    @edit[:wimg] = @wimg

    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "pxe_wimg_edit__#{@wimg.id || "new"}"
    @edit[:rec_id] = @wimg.id || nil
    @edit[:pxe_image_types] = Array.new
    PxeImageType.all.sort{|a,b| a.name <=> b.name}.collect{|img| @edit[:pxe_image_types].push([img.name,img.id])}
    @edit[:new][:img_type] = @wimg.pxe_image_type ? @wimg.pxe_image_type.id : nil

    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  def pxe_wimg_set_record_vars(wimg)
    wimg.pxe_image_type = @edit[:new][:img_type].blank? ? nil : PxeImageType.find_by_id(@edit[:new][:img_type])
  end

  def identify_pxe_server
    @ps = nil
    begin
      @record = @ps = find_by_id_filtered(PxeServer, from_cid(params[:id]))
    rescue ActiveRecord::RecordNotFound
    rescue StandardError => @bang
    end
  end

  # Delete all selected or single displayed PXE Server(s)
  def deletepxes
    pxe_button_operation('destroy', 'deletion')
  end

  def pxe_server_set_record_vars(pxe, mode = nil)
    pxe.name = @edit[:new][:name]
    pxe.access_url = @edit[:new][:access_url]
    pxe.uri_prefix = @edit[:new][:uri_prefix]
    pxe.uri = @edit[:new][:uri_prefix] + "://" + @edit[:new][:uri]
    pxe.pxe_directory = @edit[:new][:pxe_directory]
    pxe.windows_images_directory = @edit[:new][:windows_images_directory]
    pxe.customization_directory = @edit[:new][:customization_directory]
    pxe.pxe_menus.clear
    @edit[:new][:pxe_menus].each do |menu|
      pxe_menu = PxeMenu.new(:file_name=>menu)
      pxe.pxe_menus.push(pxe_menu)
    end

    creds = Hash.new
    creds[:default] = {:userid=>@edit[:new][:log_userid], :password=>@edit[:new][:log_password]}        unless @edit[:new][:log_userid].blank?
    pxe.update_authentication(creds, {:save=>(mode != :validate)})
    return true
  end

  # Get variables from edit form
  def pxe_server_get_form_vars
    @ps = @edit[:pxe_id] ? PxeServer.find_by_id(@edit[:pxe_id]) : PxeServer.new
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:protocol] = params[:log_protocol] if params[:log_protocol]
    @edit[:new][:access_url] = params[:access_url] if params[:access_url]
    @edit[:new][:uri] = params[:uri] if params[:uri]
    @edit[:new][:pxe_directory] = params[:pxe_directory] if params[:pxe_directory]
    @edit[:new][:windows_images_directory] = params[:windows_images_directory] if params[:windows_images_directory]
    @edit[:new][:customization_directory] = params[:customization_directory] if params[:customization_directory]
    params.each do |var, val|
      vars=var.split("_")
      if vars[0]=="pxemenu"
        @edit[:new][:pxe_menus][vars[1].to_i] = val
      end
    end
    #@edit[:new][:pxe_menus][0] = params[:pxe_menu_0] if params[:pxe_menu_0]
    @edit[:new][:uri_prefix] = @edit[:protocols_hash].invert[@edit[:new][:protocol]]
    @edit[:new][:log_userid] = params[:log_userid] if params[:log_userid]
    @edit[:new][:log_password] = params[:log_password] if params[:log_password]
    @edit[:new][:log_verify] = params[:log_verify] if params[:log_verify]
  end

  # Set form variables for edit
  def pxe_server_set_form_vars
    @edit = Hash.new
    @edit[:pxe_id] = @ps.id

    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "pxe_edit__#{@ps.id || "new"}"
    @edit[:rec_id] = @ps.id || nil
    @edit[:new][:name] = @ps.name
    @edit[:new][:access_url] = @ps.access_url
    @edit[:protocols_hash] = PxeServer::SUPPORTED_DEPOTS
    #have to create array to add <choose> on the top in the form
    @edit[:protocols_arr] = Array.new
    @edit[:protocols_hash].each do |p|
      @edit[:protocols_arr].push(p[1])
    end
    @edit[:new][:protocol] = @ps.uri.nil? ? nil : @edit[:protocols_hash][@ps.uri.split('://')[0]]
    @edit[:new][:uri] = @ps.uri.nil? ? nil : @ps.uri.split('://')[1]
    @edit[:new][:uri_prefix] = @ps.uri_prefix
    @edit[:new][:pxe_directory] = @ps[:pxe_directory]
    @edit[:new][:windows_images_directory] = @ps[:windows_images_directory]
    @edit[:new][:customization_directory] = @ps[:customization_directory]
    @edit[:new][:pxe_menus] = Array.new
    @ps.pxe_menus.each do |menu|
      @edit[:new][:pxe_menus].push(menu.file_name)
    end
    @edit[:new][:pxe_menus].push("") if @edit[:new][:pxe_menus].empty?
    @edit[:new][:log_userid]      = @ps.has_authentication_type?(:default) ? @ps.authentication_userid(:default).to_s : ""
    @edit[:new][:log_password]    = @ps.has_authentication_type?(:default) ? @ps.authentication_password(:default).to_s : ""
    @edit[:new][:log_verify]      = @ps.has_authentication_type?(:default) ? @ps.authentication_password(:default).to_s : ""

    @edit[:current] = copy_hash(@edit[:new])
    log_depot_set_verify_status
    session[:edit] = @edit
  end

  # Common Schedule button handler routines
  def process_pxes(pxes, task, display_name)
    process_elements(pxes, PxeServer, task, display_name)
  end

  # Get information for an event
  def pxe_server_build_tree
    TreeBuilderPxeServers.new("pxe_servers_tree", "pxe_servers", @sb)
  end

  def pxe_server_get_node_info(treenodeid)
    if treenodeid == "root"
      pxe_server_list
      @right_cell_text = @right_cell_text = I18n.t("cell_header.all_model_records",
                                :model=>ui_lookup(:models=>"PxeServer"))
      @right_cell_div  = "pxe_server_list"
    else
      @right_cell_div = "pxe_server_details"
      nodes = treenodeid.split("-")
      if (nodes[0] == "ps" && nodes.length == 2) || (["pxe_xx","win_xx"].include?(nodes[1]) && nodes.length == 3)
        # on pxe server node OR folder node is selected
        @record = @ps = PxeServer.find_by_id(from_cid(nodes.last))
        @right_cell_text = I18n.t("cell_header.model_record",
                                  :name=>@ps.name,
                                  :model=>ui_lookup(:model=>"PxeServer"))
      elsif nodes[0] == "pi"
        @record = @img = PxeImage.find_by_id(from_cid(nodes.last))
        @right_cell_text = I18n.t("cell_header.model_record",
                                  :name=>@img.name,
                                  :model=>ui_lookup(:model=>"PxeImage"))
      elsif nodes[0] == "wi"
        @record = @wimg = WindowsImage.find_by_id(from_cid(nodes[1]))
        @right_cell_text = I18n.t("cell_header.model_record",
                                :name=>@wimg.name,
                                :model=>ui_lookup(:model=>"WindowsImage"))
      end
    end
  end
end
