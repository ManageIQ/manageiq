class VdiUserController < VdiBaseController

  def index
    process_index
  end

  def button
    # button pressed on desktop pools sub-list view
    case params[:pressed]
    when 'vdi_desktop_pool_user_unassign'
      user_unassign
    when 'vdi_user_miq_request_new'
      prov_redirect
    # button pressed on desktop pools list/show screen
    when 'vdi_desktop_pool_user_assign', 'vdi_user_desktop_pool_assign'
      user_assignment
      return
    when 'vdi_user_delete'
      vdi_user_delete
      return
    when 'vdi_user_import'
      vdi_user_import
      return
    end

    if @flash_array && @lastaction == "show"
      @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end
    render :update do |page|
      if params[:pressed] == "vdi_user_miq_request_new"
        page.redirect_to :controller     => @redirect_controller,
                         :action         => @refresh_partial,
                         :id             => @redirect_id,
                         :org_controller => @org_controller,
                         :vdi_users      => @vdi_users
      elsif @refresh_div == "flash_msg_div"
        page.replace(@refresh_div, :partial=>@refresh_partial)
      end
    end
  end

  def show
    process_show(
      'vdi_desktop'      => :vdi_desktops,
      'vdi_desktop_pool' => :vdi_desktop_pools
    )
  end

  def show_list
    process_show_list
  end

  def vdi_user_import
    render :update do |page|
      page.redirect_to :action => 'user_import'     # redirect to build the retire screen
    end
  end

  def sort_users_list
    return unless load_edit("import_edit__new")
    @edit[:sortcol_idx] = params[:sortby].to_i
    @edit[:sortby]      = @edit[:col_order][params[:sortby].to_i]      # Set sortby field
    @edit[:sort_order]  = @edit[:sort_order] == "ASC" ? "DESC" : "ASC" # Set sort order

    valid_sort_keys = @edit[:users].first.keys.each_with_object({}) { |a, field| a[field] = field.to_sym }
    sorted = @edit[:users].sort_by { |usr| usr[valid_sort_keys[@edit[:sortby]]].to_s }
    sorted = sorted.reverse unless @edit[:sort_order] == "ASC"

    @edit[:users] = sorted.uniq
    @user_import = true
    set_search_fields
    render :update do |page|
      page.replace("users_list", :partial=>"users_list")
      page << "miqSparkle(false);"
    end
  end

  def vdi_user_delete
    assert_privileges("vdi_user_delete")
    delete_users = @lastaction == "show_list" ? find_checked_items : [params[:id]]
    unless params[:task_id]                       # First time thru, kick off the report generate task
      initiate_wait_for_task(:task_id => VdiUser.delete_users_queue(delete_users))
      return
    end

    miq_task = MiqTask.find(params[:task_id])

    if miq_task.task_results[:error_msgs]
      miq_task.task_results[:error_msgs].each do |err|
        add_flash(err,:error)
      end
    end

    if miq_task.task_results[:success_msgs]
      miq_task.task_results[:success_msgs].each do |msg|
        add_flash(msg)
      end
    end

    if miq_task.task_results[:warning_msgs]
      miq_task.task_results[:warning_msgs].each do |msg|
        add_flash(msg, :warning)
      end
    end
    render :update do |page|
      page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to build the retire screen
    end
  end

  def user_import
    assert_privileges("vdi_user_import")
    case params[:button]
      when "import"
        return unless load_edit("import_edit__new")
        user_import_get_form_vars
        users_to_import = Array.new
        @edit[:users].each do |u|
          users_to_import.push(u.reject!{ |k| k == :idx }) if @edit[:selected_users].include?(u[:idx])
        end

        results = VdiUser.import_from_ui(users_to_import)

        if results[:error_msgs]
          results[:error_msgs].each do |err|
            add_flash(err,:error)
          end
        end

        if results[:success_msgs]
          results[:success_msgs].each do |msg|
            add_flash(msg)
          end
        end

        if results[:warning_msgs]
          results[:warning_msgs].each do |msg|
            add_flash(msg, :warning)
          end
        end
        #reset selected users array
        @edit[:selected_users] = Array.new
        #save flash messages in session before redirect
        session[:flash_msgs] = @flash_array.dup
        redirect_to :action=>"show_list"
      when "search"
        return unless load_edit("import_edit__new")
        user_import_get_form_vars
        #reset selected users
        @edit[:selected_users] = Array.new

        options = Hash.new
        options[:ldap_region_id] = @edit[:new][:ldap_region_id]
        options[:ldap_domain_id] = @edit[:new][:ldap_domain_id] unless @edit[:new][:ldap_domain_id].nil?
        search_options = Array.new
        search_options.push({:field=>@edit[:new][:filterby1], :value=>@edit[:new][:filter_value1]}) if @edit[:new][:filterby1] != NOTHING_STRING && !@edit[:new][:filter_value1].blank?
        search_options.push({:field=>@edit[:new][:filterby2], :value=>@edit[:new][:filter_value2]}) if @edit[:new][:filterby2] != NOTHING_STRING && !@edit[:new][:filter_value2].blank?
        search_options.push({:field=>@edit[:new][:filterby3], :value=>@edit[:new][:filter_value3]}) if @edit[:new][:filterby3] != NOTHING_STRING && !@edit[:new][:filter_value3].blank?
        options[:filters] = search_options

        # need to call this block to get list of users back
        unless params[:task_id] # First time thru, kick off the generate task
          initiate_wait_for_task(:task_id => VdiUser.ldap_search_queue(options))
          return
        end
        miq_task = MiqTask.find(params[:task_id])     # Not first time, read the task record
        session[:ae_id] = params[:id]
        session[:ae_task_id] = params[:task_id]

        if miq_task.status != "Ok"  # Check to see if any results came back or status not Ok
          add_flash(I18n.t("flash.error_with_stat_message", :task=>"search", :status=>miq_task.status, :message=>miq_task.message), :error)
        else
          @edit[:headers] = Array.new
          @edit[:col_order] = Array.new
          @edit[:new][:fields].each do |f|
            @edit[:headers].push(f[0])
            @edit[:col_order].push(f[1])
          end
          users = miq_task.task_results
          @edit[:users] = users.nil? ? Array.new :
              users.sort_by { |hsh| hsh[@edit[:col_order][0].to_sym].to_s }
          # in results add idx key to each hash that can be passed upto server when checkboxes are checked and,
          # to keep track of which item was checked even after results are sorted
          @edit[:users].each_with_index do |u,i|
            u[:idx] = i
          end
          @edit[:sortcol_idx] = 0
          @edit[:sortby] = @edit[:headers][@edit[:sortcol_idx]]     # Set default sortby field
          @edit[:sort_order] = "ASC"
          @user_import = true
          @in_a_form = true
        end
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg") if @flash_array
          page.replace("form_div", :partial=>"user_import") if !@flash_array
          page << "miqSparkle(false);"
        end
      when "cancel"
        flash = I18n.t("flash.edit.user_import_cancelled")
        redirect_to :controller=>"vdi_user", :action=>"show_list", :flash_msg=>flash, :escape=>false
        return
      when "save"
        return unless load_edit("import_edit__new")
        user_import_get_form_vars
        flash = I18n.t("flash.edit.user_import_successful")
        redirect_to :action=>"show_list", :flash_msg=>flash, :flash_error=>@error, :escape=>false
        return
      else
        title = "Import VDI Users from LDAP"
        drop_breadcrumb( {:name=>title, :url=>"vdi_user_import"} )
        user_import_build_screen
        @user_import = true
        @edit[:current] = copy_hash(@edit[:new])
        session[:edit] = @edit
        @in_a_form = true
        render :action=>"show"
    end
  end

  def user_import_form_field_changed
    return unless load_edit("import_edit__new")
    user_import_get_form_vars
    buttons_show = @edit[:new][:ldap_region_id] && @filterby1 != NOTHING_STRING && !@edit[:new][:filter_value1].blank?
    render :update do |page|                    # Use JS to update the display
      page << javascript_for_miq_button_visibility(buttons_show)
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg") if @flash_array
      page.replace(@refresh_div, :partial=>@refresh_partial) if @refresh_div
      page << "miqSparkle(false);"
    end
  end

  def users_selected
    return unless load_edit("import_edit__new")
    user_import_get_form_vars
    @edit[:selected_users] ||= Array.new
    if params[:cb_all]
      if params[:cb_value] == "true"
        #check all selected
        @edit[:users].each do |u|
          @edit[:selected_users].push(u[:idx]) if u[:id].nil?
        end
      else
        #uncheck all checkbox selected
        @edit[:selected_users] = Array.new
      end
    else
      if params[:cb_value] == "true"
        @edit[:selected_users].push(params[:cb_id].to_i) unless @edit[:selected_users].include?(params[:cb_id].to_i)
      else
        @edit[:selected_users].delete(params[:cb_id].to_i)
      end
    end
    render :update do |page|                    # Use JS to update the display
      page.replace_html("selected_users_span", @edit[:selected_users].count)
      if @edit[:selected_users] && !@edit[:selected_users].empty?
        page << "$('import_buttons_on').show()"
        page << "$('import_buttons_off').hide()"
      else
        page << "$('import_buttons_on').hide()"
        page << "$('import_buttons_off').show()"
      end
      page << "miqSparkle(false);"
    end
  end

  private   ################

  def user_import_build_screen
    @edit = Hash.new
    @edit[:key] = "import_edit__new"
    @edit[:current] = Hash.new
    @edit[:new] = Hash.new
    @edit[:ldap_regions] = Array.new
    LdapRegion.valid_regions.sort{|a,b| a.name <=> b.name}.each do |ls|
      @edit[:ldap_regions].push([ls.name,ls.id])
    end
    @edit[:ldap_domains] = nil
    @edit[:users] = nil
    @edit[:new][:ldap_region_id] = nil
    @edit[:new][:fields] = VdiUser.ldap_search_fields
    @edit[:new][:filterby1] = NOTHING_STRING  # Initialize groupby fields to nothing
    @edit[:new][:filterby2] = NOTHING_STRING
    @edit[:new][:filterby3] = NOTHING_STRING
    set_search_fields
    @edit[:new][:filter_value1] = nil
    @edit[:new][:filter_value2] = nil
    @edit[:new][:filter_value3] = nil
    @edit[:selected_users] = Array.new
    @edit[:current] = copy_hash(@edit[:new])
    @in_a_form = true
  end

  def user_import_get_form_vars
    @edit[:new][:ldap_region_id] = params[:ldap_region] == "" ? nil : params[:ldap_region] if params[:ldap_region]
    if !@edit[:new][:ldap_region_id].nil? && params[:ldap_region]
      @edit[:ldap_domains] = Array.new
      @edit[:new][:ldap_domain_id] = nil
      region = LdapRegion.find_by_id(from_cid(@edit[:new][:ldap_region_id]))
      region.valid_domains.sort{|a,b| a.name <=> b.name}.each do |ld|
        @edit[:ldap_domains].push([ld.name,ld.id])
      end
    end
    @edit[:new][:ldap_domain_id] = params[:ldap_domain] == "" ? nil : params[:ldap_domain] if params[:ldap_domain]
    @edit[:ldap_domains] = @edit[:new][:ldap_domain_id] = nil if @edit[:new][:ldap_region_id].nil?
    if params[:chosen_filter1] && params[:chosen_filter1] != @edit[:new][:filterby1]
      @edit[:new][:filterby1] = params[:chosen_filter1]
      if params[:chosen_filter1] == NOTHING_STRING
        @edit[:new][:filterby2] = NOTHING_STRING
        @edit[:new][:filterby3] = NOTHING_STRING
      elsif params[:chosen_filter1] == @edit[:new][:filterby2]
        @edit[:new][:filterby2] = @edit[:new][:filterby3]
        @edit[:new][:filterby3] = NOTHING_STRING
      elsif params[:chosen_filter1] == @edit[:new][:filterby3]
        @edit[:new][:filterby3] = NOTHING_STRING
      end
    elsif params[:chosen_filter2] && params[:chosen_filter2] != @edit[:new][:filterby2]
      @edit[:new][:filterby2] = params[:chosen_filter2]
      if params[:chosen_filter2] == NOTHING_STRING || params[:chosen_filter2] == @edit[:new][:filterby3]
        @edit[:new][:filterby3] = NOTHING_STRING
      end
    elsif params[:chosen_filter3] && params[:chosen_filter3] != @edit[:new][:filterby3]
      @edit[:new][:filterby3] = params[:chosen_filter3]
    end
    if params[:chosen_filter1] || params[:chosen_filter2] || params[:chosen_filter3]
      if @edit[:new][:filterby1] == NOTHING_STRING
        @edit[:new][:filter_value1] = @edit[:new][:filter_value2] = @edit[:new][:filter_value3] = nil # Clear text value fields
      elsif @edit[:new][:filterby2] == NOTHING_STRING
        @edit[:new][:filter_value2] = @edit[:new][:filter_value3] = nil # Clear text value fields
      elsif @edit[:new][:filterby3] == NOTHING_STRING
        @edit[:new][:filter_value3] = nil # Clear text value fields
      end
      @refresh_div = "form_div"
      @refresh_partial = "user_import"
    end
    set_search_fields
    @edit[:new][:filter_value1] = params[:filter_value1] if params[:filter_value1]
    @edit[:new][:filter_value2] = params[:filter_value2] if params[:filter_value2]
    @edit[:new][:filter_value3] = params[:filter_value3] if params[:filter_value3]
    if params[:ldap_region]
      @refresh_div = "form_div"
      @refresh_partial = "user_import"
    end
  end

  # Build search pulldown arrays
  def set_search_fields
    @filters1 = @edit[:new][:fields].dup
    @filters2 = @filters1.dup.delete_if { |g| g[1] == @edit[:new][:filterby1] }
    @filters3 = @filters2.dup.delete_if { |g| g[1] == @edit[:new][:filterby2] }
    @filterby1 = @edit[:new][:filterby1]
    @filterby2 = @edit[:new][:filterby2]
    @filterby3 = @edit[:new][:filterby3]
  end

end
