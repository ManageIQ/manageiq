# Setting Accordion methods included in OpsController.rb
module OpsController::Settings
  extend ActiveSupport::Concern

  include_concern 'AnalysisProfiles'
  include_concern 'CapAndU'
  include_concern 'Common'
  include_concern 'Ldap'
  include_concern 'Schedules'
  include_concern 'Tags'
  include_concern 'Upload'
  include_concern 'Zones'
  include_concern 'RHN'

  # Send the smartproxy build file
  def fetch_build
    prd_update = ProductUpdate.find(from_cid(params[:id]))
    download_file = prd_update.file_from_db
    disable_client_cache
    send_file(download_file)
  end

  def activate
    @server = MiqServer.find(@sb[:selected_server_id])
    @product_update = ProductUpdate.find(from_cid(params[:id]))
    @build = @product_update
    if params[:button] == "activate"
      message = "Feature Disabled, see RHN tab on Region."
      product_updates_list
      add_flash(_("Error during %s: ") % "Build activation" << message, :error)
      get_node_info(x_node)
      replace_right_cell(@nodetype)
    else      #cancel button is pressed
      audit = {:event=>"productupdate_record_activated", :message=>"[#{@product_update.name}] Build activated", :target_id=>@product_update.id, :target_class=>"ProductUpdate", :userid => session[:userid]}
        AuditEvent.success(audit)
      @sb[:buildinfo] = nil
      @sb[:activating] = false
      @build = nil
      get_node_info(x_node)
      replace_right_cell(@nodetype)
    end
  end

  # Apply the good records from an uploaded import file
  def apply_imports
    if session[:imports]
      begin
        session[:imports].apply
      rescue StandardError => bang
        msg = _("Error during '%s': ") % "apply" << bang
        err = true
      else
        msg = _("Records were successfully imported")
        err = false
        session[:imports] = @sb[:imports] = nil
      end
    else
      msg = _("Use the Browse button to locate %s file") % "CSV"
      err = true
    end
    @sb[:show_button] = err
    redirect_to :action => 'explorer', :flash_msg=>msg, :flash_error=>err, :no_refresh=>true
  end

  def delete_build
    assert_privileges("delete_build")
    builds = Array.new
    builds = find_checked_items
    if builds.empty?
      add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:models=>"ProductUpdate"), :task=>"deletion"}, :error)
      render :update do |page|                    # Use RJS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    else
      process_builds(builds,'destroy')
      product_updates_list
      settings_get_info(x_node)
      replace_right_cell(x_node,[:settings])
    end
  end

  # Show the main Builds list view
  def product_updates_list
    @gtl_type = "list"
    if params[:ppsetting]                                       # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                 # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page   # Set the per page setting for this gtl type
    end

    @no_listicon = true   # Don't show icons in list view
    @showlinks = true     # Don't show links, read only
    @ajax_paging_buttons = true
    @lastaction = "product_updates_list"
    @view, @pages = get_view(ProductUpdate) # Get the records (into a view) and the paginator

    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page]
      render :update do |page|
        page.replace_html("gtl_div", :partial=>"layouts/x_gtl", :locals=>{:action_url=>"product_updates_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  def show_product_update
    @sb[:activating] = true
    @build = ProductUpdate.find(from_cid(params[:id]))
    @sb[:buildinfo] = [
      ["Name", @build.name],
      ["Description", @build.description],
      ["Type", @build.update_type],
      ["Platform", @build.platform],
      ["Component", @build.component],
      ["Architecture", @build.arch],
      ["Version", @build.version]
    ]
    redirect_to :action => 'explorer', :no_refresh=>true, :cls_id=>"b_#{@build.id}"
  end

  def forest_get_form_vars
    @edit = session[:edit]
    @temp = Hash.new
    @temp[:mode] = params[:user_proxies][:mode] if params[:user_proxies] && params[:user_proxies][:mode]
    @temp[:ldaphost] = params[:user_proxies][:ldaphost] if params[:user_proxies] && params[:user_proxies][:ldaphost]
    @temp[:ldapport] = params[:user_proxies][:ldapport] if params[:user_proxies] && params[:user_proxies][:ldapport]
    @temp[:basedn] = params[:user_proxies][:basedn] if params[:user_proxies] && params[:user_proxies][:basedn]
    @temp[:bind_dn] = params[:user_proxies][:bind_dn] if params[:user_proxies] && params[:user_proxies][:bind_dn]
    @temp[:bind_pwd] = params[:user_proxies][:bind_pwd] if params[:user_proxies] && params[:user_proxies][:bind_pwd]
    return
  end

  def forest_form_field_changed
    @edit = session[:edit]  # Need to reload @edit so it stays in the session
    port = params[:user_proxies_mode] == "ldap" ? "389" : "636"
    render :update do |page|
      page << "$('#user_proxies_ldapport').val('#{port}');"
    end
  end

  # AJAX driven routine to select a classification entry
  def forest_select
    forest_get_form_vars
    if params[:ldaphost_id] == "new"
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("forest_entries_div", :partial=>"ldap_forest_entries", :locals=>{:entry=>"new", :edit=>true})
      end
      session[:entry] = "new"
    else
      entry = nil
      @edit[:new][:authentication][:user_proxies].each do |f|
        entry = f if f[:ldaphost] == params[:ldaphost_id]
      end
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("forest_entries_div", :partial=>"ldap_forest_entries", :locals=>{:entry=>entry, :edit=>true})
      end
      session[:entry] = entry
    end
  end

  # AJAX driven routine to delete a classification entry
  def forest_delete
    forest_get_form_vars
    idx = nil
    @edit[:new][:authentication][:user_proxies].each_with_index do |f,i|
      idx = i if f[:ldaphost] == params[:ldaphost_id]
    end
    @edit[:new][:authentication][:user_proxies].delete_at(idx) if !idx.nil?
    @changed = (@edit[:new] != @edit[:current].config)
    render :update do |page|                        # Use JS to update the display
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page << javascript_for_miq_button_visibility(@changed)
      page.replace("forest_entries_div", :partial=>"ldap_forest_entries", :locals=>{:entry=>nil, :edit=>false})
    end
  end

  # AJAX driven routine to add/update a classification entry
  def forest_accept
    forest_get_form_vars
    no_changes = true
    if @temp[:ldaphost] == ""
      add_flash(_("%s is required") % "LDAP Host", :error)
      no_changes = false
    elsif @edit[:new][:authentication][:user_proxies].blank? || @edit[:new][:authentication][:user_proxies][0].blank?   # if adding forest first time, delete a blank record
      @edit[:new][:authentication][:user_proxies].delete_at(0)
    else
      @edit[:new][:authentication][:user_proxies].each do |f|
        if f[:ldaphost] == @temp[:ldaphost] && session[:entry][:ldaphost] != @temp[:ldaphost]   #check to make sure ldaphost already doesn't exist and ignore if existing record is being edited.
          no_changes = false
          add_flash(_("%s should be unique") % "LDAP Host", :error)
          break
        end
      end
    end
    if no_changes
      if session[:entry] == "new"
        @edit[:new][:authentication][:user_proxies].push(@temp)
      else
        @edit[:new][:authentication][:user_proxies].each_with_index do |f,i|
          @edit[:new][:authentication][:user_proxies][i] = @temp if f[:ldaphost] == session[:entry][:ldaphost]
        end
      end
    end
    @changed = (@edit[:new] != @edit[:current].config)
    render :update do |page|                        # Use JS to update the display
      page << javascript_for_miq_button_visibility(@changed)
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      page.replace("forest_entries_div", :partial=>"ldap_forest_entries", :locals=>{:entry=>nil, :edit=>false})  if no_changes
    end
  end

  def validate_replcation_worker
    settings_load_edit
    return unless @edit
    wb = @edit[:new].config[:workers][:worker_base]
    w = wb[:replication_worker][:replication][:destination]
    valid = MiqRegionRemote.validate_connection_settings(w[:host],w[:port],w[:username],w[:password],w[:database])
    if valid.nil?
      add_flash(_("%s Credentials validated successfully") % "Replication Worker")
    else
      valid.each do |v|
        add_flash(v,:error)
      end
    end
    render :update do |page|
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
    end
  end

  def region_edit
    settings_set_view_vars
    @right_cell_text = _("%{typ} %{model} \"%{name}\"") % {:typ=>"Settings", :name=>"#{MiqRegion.my_region.description} [#{MiqRegion.my_region.region}]", :model=>ui_lookup(:model=>"MiqRegion")}
    case params[:button]
    when "cancel"
      session[:edit] = @edit = nil
      replace_right_cell("root")
    when "save"
      return unless load_edit("region_edit__#{params[:id]}","replace_cell__explorer")
      if @edit[:new][:description].nil? || @edit[:new][:description] == ""
        add_flash(_("%s is required") % "Region description", :error)
      end
      if @flash_array != nil
        session[:changed] = @changed = true
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        return
      end
      @edit[:region].description = @edit[:new][:description]
      begin
        @edit[:region].save!
      rescue StandardError => bang
        @edit[:region].errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        @changed = true
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        add_flash(_("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:model=>"MiqRegion"), :name=>@edit[:region].description})
        AuditEvent.success(build_saved_audit(@edit[:region], params[:button] == "edit"))
        @edit = session[:edit] = nil  # clean out the saved info
        replace_right_cell("root",[:settings])
      end
    when "reset", nil # Reset or first time in
      region_set_form_vars
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("root")
    end
  end

  def region_form_field_changed
    return unless load_edit("region_edit__#{params[:id]}","replace_cell__explorer")
    region_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  private ############################

  def region_set_form_vars
    @edit = Hash.new
    @edit[:region] = MiqRegion.my_region
    @edit[:key] = "region_edit__#{@edit[:region].id}"
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:new][:description] = @edit[:region].description
    @edit[:current] = copy_hash(@edit[:new])
  end

  def region_get_form_vars
    @edit[:new][:description] = params[:region_description] if params[:region_description]
  end

  # Common Product Updates button handler routines follow
  def process_builds(builds, task)
    process_elements(builds, ProductUpdate, task)
  end

  # Set filters in the user record from the @edit[:new] hash values
  def user_set_filters(user)
    @set_filter_values = []
    @edit[:new][:filters].each do | key, value |
      @set_filter_values.push(value)
    end
    user_make_subarrays # Need to have category arrays of item arrays for and/or logic
    user.set_managed_filters(@set_filter_values)
    user.set_belongsto_filters(@edit[:new][:belongsto].values)  # Set belongs to to hash values
  end

  # Need to make arrays by category containing arrays of items so the filtering logic can apply
  # AND between the categories, but OR between the items within a category
  def user_make_subarrays
    # moved into common method used by ops_rbac module as well
    rbac_and_user_make_subarrays
  end

  def set_verify_status
    @edit[:default_verify_status] = (@edit[:new][:password] == @edit[:new][:verify])
  end

end
