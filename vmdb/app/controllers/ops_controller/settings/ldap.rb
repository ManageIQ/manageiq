module OpsController::Settings::Ldap
  extend ActiveSupport::Concern

  # Show the main LdapRegions list view
  def ldap_regions_list
    ldap_region_build_list

    if !params[:button] && (params[:ppsetting]   || params[:searchtag] || params[:entry] || params[:sort_choice] || params[:page])
      render :update do |page|
        page.replace("gtl_div", :partial=>"layouts/x_gtl", :locals=>{:action_url=>"ldap_regions_list"})
        page.replace_html("paging_div", :partial=>"layouts/x_pagingcontrols")
        page << "miqSparkle(false);"  # Need to turn off sparkle in case original ajax element gets replaced
      end
    end
  end

  def ldap_region_show
    @display = "main"
    return if record_no_longer_exists?(@selected_lr)
  end

  def ldap_domain_show
    @display = "main"
    return if record_no_longer_exists?(@selected_ld)
  end

  def ldap_region_add
    @_params[:typ] = "new"
    ldap_region_edit
  end

  def ldap_region_edit
    case params[:button]
      when "cancel"
        if !session[:edit][:ldap_region_id]
          add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"LdapRegion"))
        else
          add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"LdapRegion"), :name=>session[:edit][:new][:name]})
        end
        get_node_info(x_node)
        @ldap_region = nil
        @edit = session[:edit] = nil  # clean out the saved info
        replace_right_cell(@nodetype)
      when "save", "add"
        id = params[:id] ? params[:id] : "new"
        return unless load_edit("ldap_region_edit__#{id}","replace_cell__explorer")
        ldap_region_get_form_vars
        if @edit[:new][:name].blank?
          add_flash(_("%s is required") % "Name", :error)
        end

        if @flash_array
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
          return
        end

        ldap_region_set_record_vars(@ldap_region)
        if @ldap_region.valid? && !flash_errors? && @ldap_region.save
          AuditEvent.success(build_saved_audit(@ldap_region, params[:button] == "add"))
          add_flash(_("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:model=>"LdapRegion"), :name=>@ldap_region.name})
          @edit = session[:edit] = nil  # clean out the saved info
          if params[:button] == "add"
            self.x_node  = "xx-l"  # reset node to show list
            ldap_regions_list
            settings_get_info("st")
          else          #set selected ldap_region
            self.x_node = "lr-#{to_cid(@ldap_region.id)}"
            get_node_info(x_node)
          end
          replace_right_cell("root",[:settings])
        else
          @ldap_region.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          @changed = session[:changed] = (@edit[:new] != @edit[:current])
          render :update do |page|
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        end
      when "reset", nil # Reset or first time in
        obj = find_checked_items
        obj[0] = params[:id] if obj.blank? && params[:id]
        @ldap_region = params[:typ] == "new" ? LdapRegion.new : LdapRegion.find_by_id(from_cid(obj[0]))         # Get existing or new record
        ldap_region_set_form_vars
        @in_a_form = true
        session[:changed] = false
        if params[:button] == "reset"
          add_flash(_("All changes have been reset"), :warning)
        end
        replace_right_cell("lre")
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def ldap_region_form_field_changed
    return unless load_edit("ldap_region_edit__#{params[:id]}","replace_cell__explorer")
    ldap_region_get_form_vars
    render :update do |page|                    # Use JS to update the display
      @changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(@changed)
      page << "miqSparkle(false);"
    end
  end

    # Delete all selected or single displayed action(s)
  def ldap_region_delete
    ldap_regions = Array.new
    if !params[:id] # showing a list
      ldap_regions = find_checked_items
      if ldap_regions.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>"ldap_region"), :task=>"deletion"}, :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
      process_ldap_regions(ldap_regions, "destroy") unless ldap_regions.empty?
    else # showing 1 ldap_region, delete it
      if params[:id] == nil || LdapRegion.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:table=>"ldap_region"), :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      else
        ldap_regions.push(params[:id])
      end
      process_ldap_regions(ldap_regions, "destroy") if ! ldap_regions.empty?
    end
    self.x_node = "xx-l"
    get_node_info(x_node)
    replace_right_cell(x_node,[:settings])
  end

  def ldap_domain_add
    @_params[:typ] = "new"
    @_params[:region_id] = x_node.split('-').last
    ldap_domain_edit
  end

  def ldap_domain_edit
    if params[:button] == "verify"
      return unless load_edit("ldap_domain_edit__#{params[:domain_id]}","replace_cell__explorer")
      ldap_domain_get_form_vars
      ldap_domain = params[:domain_id] == "new" ? LdapDomain.new : LdapDomain.find_by_id(from_cid(params[:domain_id]))
      ldap_domain_set_record_vars(ldap_domain,:validate)
      ldap_server = ldap_domain.ldap_servers[params[:id].to_i]
      @in_a_form = true
      begin
        ldap_server.verify_credentials
      rescue StandardError=>bang
        add_flash("#{bang}", :error)
      else
        add_flash(_("Credential validation was successful"))
      end
      render :update do |page|
        page.replace("flash_msg_div_entries", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"entries"})
      end
    elsif params[:button] == "cancel"
      @ldap_domain = session[:edit][:ldap_domain] if session[:edit] && session[:edit][:ldap_domain]
      if !@ldap_domain || @ldap_domain.id.blank?
        add_flash(_("Add of new %s was cancelled by the user") % ui_lookup(:model=>"LdapDomain"))
      else
        add_flash(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>ui_lookup(:model=>"Ldapomain"), :name=>@ldap_domain.name})
      end
      get_node_info(x_node)
      @ldap_domain = nil
      @edit = session[:edit] = nil  # clean out the saved info
      replace_right_cell(@nodetype)
    elsif params[:button] == "save" || params[:button] == "add"
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("ldap_domain_edit__#{id}","replace_cell__explorer")
      ldap_domain_get_form_vars
      if @edit[:new][:name].blank?
        add_flash(_("%s is required") % "Name", :error)
      end

      if !@edit[:new][:bind_pwd].blank? && @edit[:new][:bind_dn].blank?
        add_flash(_("User ID must be entered if Password is entered"), :error)
      end

      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        return
      end

      ldap_domain_set_record_vars(@ldap_domain)
      if @ldap_domain.valid? && !flash_errors? && @ldap_domain.save
        AuditEvent.success(build_saved_audit(@ldap_domain, params[:button] == "add"))
        add_flash(_("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:model=>"LdapDomain"), :name=>@ldap_domain.name})
        @in_a_form = @edit = session[:edit] = nil # clean out the saved info
        if params[:button] == "add"
          self.x_node  = "lr-#{to_cid(@ldap_domain.ldap_region_id)}"  # reset node to show list
        else          #set selected ldap_domain
          self.x_node = "ld-#{to_cid(@ldap_domain.id)}"
        end
        get_node_info(x_node)
        replace_right_cell(x_node,[:settings])
      else
        @ldap_domain.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        @changed = session[:changed] = (@edit[:new] != @edit[:current])
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
    elsif params[:accept]
      id = params[:id] ? params[:id] : "new"
      return unless load_edit("ldap_domain_edit__#{id}","replace_cell__explorer")
      ldap_domain_get_form_vars
      if params[:entry]
        server = Hash.new
        server[:hostname] = params[:entry][:hostname]
        if params[:entry][:hostname] == ""
          add_flash(_("%s is required") % "Host Name", :error)
          render :update do |page|                    # Use JS to update the display
            page.replace("flash_msg_div_entries", :partial=>"layouts/flash_msg", :locals=>{:div_num=>"entries"})
          end
          return
        else
          server[:mode] = params[:entry_mode]
          server[:port] = params[:entry][:port] == "" ? (server[:mode] == "ldap" ? "389" : "636") : params[:entry][:port]
          server[:bind_dn] = params[:entry][:bind_dn]
          server[:bind_pwd] = params[:entry][:bind_pwd]
          if params[:entry][:idx]
            #update existing one
            @edit[:new][:ldap_servers][params[:entry][:idx].to_i] = server
          else
            #add new entry
            @edit[:new][:ldap_servers].push(server)
          end
        end
        @in_a_form = true
        @changed = true
        render :update do |page|
          page.replace("ldap_server_entries_div", :partial=>"ldap_server_entries", :locals=>{:entry=>nil, :edit=>false,:domain_id=>params[:id]})
          page << javascript_for_miq_button_visibility(@changed)
        end
      end
    else  # Reset or first time in
      obj = find_checked_items
      obj[0] = params[:id] if obj.blank? && params[:id]
      @ldap_domain = params[:typ] == "new" ? LdapDomain.new : LdapDomain.find_by_id(from_cid(obj[0]))         # Get existing or new record
      ldap_domain_set_form_vars
      @in_a_form = true
      session[:changed] = false
      if params[:button] == "reset"
        add_flash(_("All changes have been reset"), :warning)
      end
      replace_right_cell("lde")
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def ldap_domain_form_field_changed
    return unless load_edit("ldap_domain_edit__#{params[:id]}","replace_cell__explorer")
    ldap_domain_get_form_vars
    render :update do |page|                    # Use JS to update the display
      if @authusertype_changed
        if @edit[:new][:user_type] == "dn-cn"
          page << javascript_hide("upn-mail_prefix")
          page << javascript_hide("dn-uid_prefix")
          page << javascript_show("dn-cn_prefix")
        elsif @edit[:new][:user_type] == "dn-uid"
          page << javascript_hide("upn-mail_prefix")
          page << javascript_hide("dn-cn_prefix")
          page << javascript_show("dn-uid_prefix")
        else
          page << javascript_hide("dn-cn_prefix")
          page << javascript_hide("dn-uid_prefix")
          page << javascript_show("upn-mail_prefix")
        end
      end
      @changed = (@edit[:new] != @edit[:current])
      page << javascript_for_miq_button_visibility(@changed)
      page << "miqSparkle(false);"
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def ldap_entry_changed
    return unless load_edit("ldap_domain_edit__#{params[:id]}","replace_cell__explorer")
    ldap_domain_get_form_vars
    render :update do |page|                    # Use JS to update the display
      page << "$('#entry_port').val('#{params[:entry_mode] == "ldaps" ? '636' : '389' }');"
      page << "miqSparkle(false);"
    end
  end

  # Delete all selected or single displayed action(s)
  def ldap_domain_delete
    ldap_domains = Array.new
    if params[:id] == nil || LdapDomain.find_by_id(params[:id]).nil?
      add_flash(_("%s no longer exists") % ui_lookup(:table=>"ldap_domain"), :error)
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    else
      ldap_domains.push(params[:id])
    end
    ld = LdapDomain.find_by_id(params[:id])
    self.x_node = "lr-#{ld.ldap_region_id}"
    process_ldap_domains(ldap_domains, "destroy") if ! ldap_domains.empty?
    get_node_info(x_node)
    replace_right_cell(x_node,[:settings])
  end

  # AJAX driven routine to select a classification entry
  def ls_select
    return unless load_edit("ldap_domain_edit__#{params[:domain_id]}","replace_cell__explorer")
    ldap_domain_get_form_vars
    if params[:id] == "new"
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("ldap_server_entries_div", :partial=>"ldap_server_entries", :locals=>{:entry=>"new", :edit=>true,:domain_id=>params[:domain_id]})
        page << javascript_focus('entry_name')
        page << "$('#entry_name').select();"
      end
      session[:entry] = "new"
    else
      entry = params[:id]
      render :update do |page|                    # Use JS to update the display
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page.replace("ldap_server_entries_div", :partial=>"ldap_server_entries", :locals=>{:entry=>entry, :edit=>true,:domain_id=>params[:domain_id]})
        page << javascript_focus("entry_#{j_str(params[:field])}")
        page << "$('#entry_#{j_str(params[:field])}').select();"
      end
      session[:entry] = entry
    end
  end

  # AJAX driven routine to delete a classification entry
  def ls_delete
    return unless load_edit("ldap_domain_edit__#{params[:domain_id]}","replace_cell__explorer")
    ldap_domain_get_form_vars
    @edit[:new][:ldap_servers].delete_at(params[:id].to_i)
    @changed = true
    render :update do |page|
      page.replace("ldap_server_entries_div", :partial=>"ldap_server_entries", :locals=>{:entry=>nil, :edit=>false,:domain_id=>params[:domain_id]})
      page << javascript_for_miq_button_visibility(@changed)
    end
  end

  private

  # Create the view and associated vars for the ldap_regions list
  def ldap_region_build_list
    @lastaction = "ldap_regions_list"
    @force_no_grid_xml = true
    @gtl_type = "list"
    @ajax_paging_buttons = true
    if params[:ppsetting]                                             # User selected new per page value
      @items_per_page = params[:ppsetting].to_i                       # Set the new per page value
      @settings[:perpage][@gtl_type.to_sym] = @items_per_page         # Set the per page setting for this gtl type
    end
    @sortcol = session[:ldap_region_sortcol] == nil ? 0 : session[:ldap_region_sortcol].to_i
    @sortdir = session[:ldap_region_sortdir] == nil ? "ASC" : session[:ldap_region_sortdir]

    @view, @pages = get_view(LdapRegion) # Get the records (into a view) and the paginator

    @current_page = @pages[:current] if @pages != nil # save the current page number
    session[:ldap_region_sortcol] = @sortcol
    session[:ldap_region_sortdir] = @sortdir
  end

  # Set form variables for edit
  def ldap_region_set_form_vars
    @edit = Hash.new

    @edit[:ldap_region_id] = @ldap_region.id
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "ldap_region_edit__#{@ldap_region.id || "new"}"

    @edit[:new][:name] = @ldap_region.name
    @edit[:new][:description] = @ldap_region.description
    @edit[:new][:zone_id] = @ldap_region.zone ? @ldap_region.zone.id : nil
    @edit[:zones] = Array.new
    Zone.all.sort{|a,b| a.name.to_s <=> b.name.to_s}.each do |zone|
      @edit[:zones].push([zone.name,zone.id])
    end
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  # Get variables from edit form
  def ldap_region_get_form_vars
    @ldap_region = @edit[:ldap_region_id] ? LdapRegion.find_by_id(@edit[:ldap_region_id]) : LdapRegion.new
    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:description] = params[:description] if params[:description]
    @edit[:new][:zone_id] = params[:zone_id] if params[:zone_id]
  end

  # Set record variables to new values
  def ldap_region_set_record_vars(ldap_region)
    ldap_region.name = @edit[:new][:name]
    ldap_region.description = @edit[:new][:description]
    ldap_region.zone = Zone.find_by_id(from_cid(@edit[:new][:zone_id]))
  end

  # Common ldap_region button handler routines follow
  def process_ldap_regions(ldap_regions, task)
    process_elements(ldap_regions, LdapRegion, task)
  end

  # Set form variables for edit
  def ldap_domain_set_form_vars
    @edit = Hash.new

    @edit[:ldap_domain_id] = @ldap_domain.id
    @edit[:ldap_region_id] = @ldap_domain.id ? @ldap_domain.ldap_region_id : params[:region_id]
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new
    @edit[:key] = "ldap_domain_edit__#{@ldap_domain.id || "new"}"

    @edit[:new][:name] = @ldap_domain.name
    @edit[:new][:user_type] = @ldap_domain.user_type ? @ldap_domain.user_type : "userprincipalname"
    @edit[:new][:user_suffix] = @ldap_domain.user_suffix
    @edit[:new][:domain_prefix] = @ldap_domain.domain_prefix
    @edit[:new][:get_user_groups] = @ldap_domain.get_user_groups ? @ldap_domain.get_user_groups : false
    @edit[:new][:get_direct_groups] = @ldap_domain.get_direct_groups
    @edit[:new][:follow_referrals] = @ldap_domain.follow_referrals ? @ldap_domain.follow_referrals : false
    @edit[:new][:base_dn] = @ldap_domain.base_dn
    @edit[:new][:bind_dn] = @ldap_domain.authentication_userid
    @edit[:new][:bind_pwd] = @ldap_domain.authentication_password
    @edit[:new][:ldap_servers] = Array.new
    @ldap_domain.ldap_servers.sort{|a,b| a.hostname.to_s <=> b.hostname.to_s}.each do |svr|
      server = Hash.new
      server[:id] = svr.id
      server[:hostname] = svr.hostname
      server[:mode] = svr.mode
      server[:port] = svr.port
      @edit[:new][:ldap_servers].push(server)
    end

    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
  end

  # Get variables from edit form
  def ldap_domain_get_form_vars
    @ldap_domain = @edit[:ldap_domain_id] ? LdapDomain.find_by_id(@edit[:ldap_domain_id]) : LdapDomain.new

    @edit[:new][:name] = params[:name] if params[:name]
    @sb[:get_user_groups] = (params[:get_user_groups].to_s == "1") if params[:get_user_groups]
    if params[:user_type] && params[:user_type] != @edit[:new][:user_type]
      @authusertype_changed = true
    end
    @edit[:new][:user_suffix] = params[:user_suffix] if params[:user_suffix]
    @edit[:new][:domain_prefix] = params[:domain_prefix] if params[:domain_prefix]
    if @sb[:get_user_groups] != @edit[:new][:get_user_groups]
      @edit[:new][:get_user_groups] = @sb[:get_user_groups]
      @authldaprole_changed = true
    end
    @edit[:new][:port] = params[:port] if params[:port]
    @edit[:new][:user_type] = params[:user_type] if params[:user_type]
    @edit[:new][:base_dn] = params[:base_dn] if params[:base_dn]
    @edit[:new][:bind_dn] = params[:bind_dn] if params[:bind_dn]
    @edit[:new][:bind_pwd] = params[:bind_pwd] if params[:bind_pwd]
    @edit[:new][:follow_referrals] = (params[:follow_referrals].to_s == "1") if params[:follow_referrals]
    @edit[:new][:get_direct_groups] = (params[:get_direct_groups].to_s == "1") if params[:get_direct_groups]
  end

  # Set record variables to new values
  def ldap_domain_set_record_vars(ldap_domain, mode = nil)
    ldap_domain.name = @edit[:new][:name]
    ldap_domain.user_type = @edit[:new][:user_type]
    ldap_domain.user_suffix = @edit[:new][:user_suffix]
    ldap_domain.domain_prefix = @edit[:new][:domain_prefix]
    ldap_domain.get_user_groups = @edit[:new][:get_user_groups]
    ldap_domain.get_direct_groups = @edit[:new][:get_direct_groups]
    ldap_domain.follow_referrals = @edit[:new][:follow_referrals]
    ldap_domain.base_dn = @edit[:new][:base_dn]
    ldap_domain.ldap_region = LdapRegion.find_by_id(from_cid(@edit[:ldap_region_id])) if ldap_domain.ldap_region.nil?
    creds = Hash.new
    creds[:default] = {:userid=>@edit[:new][:bind_dn], :password=>@edit[:new][:bind_pwd]} unless @edit[:new][:bind_dn].blank?
    ldap_domain.update_authentication(creds, {:save=>(mode != :validate)})

    ldap_servers = Array.new
    if !@edit[:new][:ldap_servers].blank?
      @edit[:new][:ldap_servers].each do |svr|
        ldap_server = LdapServer.new
        ldap_server.hostname = svr[:hostname]
        ldap_server.mode = svr[:mode]
        ldap_server.port = svr[:port]
        ldap_servers.push(ldap_server)
      end
    end
    ldap_domain.ldap_servers = ldap_servers
  end

  # Common ldap_domain button handler routines follow
  def process_ldap_domains(ldap_domains, task)
    process_elements(ldap_domains, LdapDomain, task)
  end

end
