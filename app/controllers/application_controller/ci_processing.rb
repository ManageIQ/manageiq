module ApplicationController::CiProcessing
  extend ActiveSupport::Concern

  included do
    private(:process_elements)
  end

  # Set Ownership selected db records
  def set_ownership(klass = "VmOrTemplate")
    assert_privileges(params[:pressed])
    @edit = {}
    @edit[:key] = "ownership_edit__new"
    @edit[:current] = {}
    @edit[:new] = {}
    @edit[:klass] = klass.constantize
    # check to see if coming from show_list or drilled into vms from another CI
    if request.parameters[:controller] == "vm" || ["all_vms", "vms", "instances", "images"].include?(params[:display])
      rec_cls = "vm"
    elsif ["miq_templates", "images"].include?(params[:display]) || params[:pressed].starts_with?("miq_template_")
      rec_cls = "miq_template"
    else
      rec_cls = request.parameters[:controller]
    end
    recs = []
    if !session[:checked_items].nil? && @lastaction == "set_checked_items"
      recs = session[:checked_items]
    else
      recs = find_checked_items
    end
    if recs.blank?
      recs = [params[:id].to_i]
    end
    if recs.length < 1
      add_flash(_("One or more %{model} must be selected to Set Ownership") % {
        :model => Dictionary.gettext(db.to_s, :type => :model, :notfound => :titleize, :plural => true)}, :error)
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
      return
    else
      @edit[:ownership_items] = recs.collect(&:to_i)
    end

    if @explorer
      @edit[:explorer] = true
      ownership
    else
      render :update do |page|
        if role_allows(:feature => "vm_ownership")
          page.redirect_to :controller => "#{rec_cls}", :action => 'ownership'              # redirect to build the ownership screen
        end
      end
    end
  end
  alias_method :image_ownership, :set_ownership
  alias_method :instance_ownership, :set_ownership
  alias_method :vm_ownership, :set_ownership
  alias_method :miq_template_ownership, :set_ownership
  alias_method :service_ownership, :set_ownership

  # Assign/unassign ownership to a set of objects
  def ownership
    @edit = session[:edit] unless @explorer  # only do this for non-explorer screen
    ownership_build_screen
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
    drop_breadcrumb(:name => _("Set Ownership"), :url => "/vm_common/ownership")
    @in_a_form = @ownershipedit = true
    build_targets_hash(@ownershipitems)
    if @edit[:explorer]
      @refresh_partial = "shared/views/ownership"
    else
      render :action => "show"
    end
  end

  DONT_CHANGE_OWNER = "0"

  # Build the ownership assignment screen
  def ownership_build_screen
    @users = {}   # Users array for first chooser
    User.with_current_user_groups.each { |u| @users[u.name] = u.id.to_s }
    record = @edit[:klass].find(@edit[:ownership_items][0])
    user = record.evm_owner if @edit[:ownership_items].length == 1
    @edit[:new][:user] = user ? user.id.to_s : nil            # Set to first category, if not already set

    @groups = {}                    # Create new entries hash (2nd pulldown)
    # need to do this only if 1 vm is selected and miq_group has been set for it
    group = record.miq_group if @edit[:ownership_items].length == 1
    @edit[:new][:group] = group ? group.id.to_s : nil
    MiqGroup.with_current_user_groups.each { |g| @groups[g.description] = g.id.to_s }

    @edit[:new][:user] = @edit[:new][:group] = DONT_CHANGE_OWNER if @edit[:ownership_items].length > 1

    @ownershipitems = @edit[:klass].find(@edit[:ownership_items]).sort_by(&:name) # Get the db records that are being tagged
    @view = get_db_view(@edit[:klass] == VmOrTemplate ? Vm : @edit[:klass])       # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@ownershipitems, @view.cols + ['id'])
  end

  def ownership_field_changed
    return unless load_edit("ownership_edit__new")
    ownership_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page << javascript_for_miq_button_visibility(changed)
    end
  end

  def ownership_get_form_vars
    @edit[:new][:user] = params[:user_name] if params[:user_name]
    @edit[:new][:group] = params[:group_name] if params[:group_name]
  end

  def ownership_update
    return unless load_edit("ownership_edit__new")
    ownership_get_form_vars
    case params[:button]
    when "cancel"
      add_flash(_("Set Ownership was cancelled by the user"))
      if @edit[:explorer]
        @edit = @sb[:action] = nil
        replace_right_cell
      else
        session[:flash_msgs] = @flash_array
        render :update do |page|
          page.redirect_to(previous_breadcrumb_url)
        end
      end
    when "save"
      opts = {}
      unless @edit[:new][:user] == DONT_CHANGE_OWNER
        if owner_changed?(:user)
          opts[:owner] = User.find(@edit[:new][:user])
        elsif @edit[:new][:user].blank?     # to clear previously set user
          opts[:owner] = nil
        end
      end

      unless @edit[:new][:group] == DONT_CHANGE_OWNER
        if owner_changed?(:group)
          opts[:group] = MiqGroup.find_by_id(@edit[:new][:group])
        elsif @edit[:new][:group].blank?    # to clear previously set group
          opts[:group] = nil
        end
      end

      result = @edit[:klass].set_ownership(@edit[:ownership_items], opts)
      unless result == true
        result["missing_ids"].each { |msg| add_flash(msg, :error) } if result["missing_ids"]
        result["error_updating"].each { |msg| add_flash(msg, :error) } if result["error_updating"]
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        object_types = object_types_for_flash_message(@edit[:klass], @edit[:ownership_items])

        flash = _("Ownership saved for selected %{object_types}") % {:object_types => object_types}
        add_flash(flash)
        if @edit[:explorer]
          @edit = @sb[:action] = nil
          replace_right_cell
        else
          session[:flash_msgs] = @flash_array
          render :update do |page|
            page.redirect_to(previous_breadcrumb_url)
          end
        end
      end
    when "reset"
      @in_a_form = true
      if @edit[:explorer]
        ownership
        add_flash(_("All changes have been reset"), :warning)
        request.parameters[:controller] == "service" ? replace_right_cell("ownership") : replace_right_cell
      else
        render :update do |page|
          page.redirect_to :action        => 'ownership',
                           :flash_msg     => _("All changes have been reset"),
                           :flash_warning => true,
                           :escape        => true
        end
      end
    end
  end

  # Retire 1 or more VMs
  def retirevms
    assert_privileges(params[:pressed])
    vms = find_checked_items
    if VmOrTemplate.includes_template?(vms.map(&:to_i).uniq)
      add_flash(_("Set Retirement Date does not apply to selected %{model}") %
        {:model => ui_lookup(:table => "miq_template")}, :error)
      render_flash_and_scroll
      return
    end
    # check to see if coming from show_list or drilled into vms from another CI
    if request.parameters[:controller] == "vm" || %w(all_vms instances vms).include?(params[:display])
      rec_cls = "vm"
    elsif request.parameters[:controller] == "service"
      rec_cls =  "service"
    elsif request.parameters[:controller] == "orchestration_stack"
      rec_cls = "orchestration_stack"
    end
    if vms.blank?
      session[:retire_items] = [params[:id]]
    else
      if vms.length < 1
        add_flash(_("At least one %{model} must be selected for tagging") %
          {:model => ui_lookup(:model => "Vm")}, :error)
        @refresh_div = "flash_msg_div"
        @refresh_partial = "layouts/flash_msg"
        return
      else
        session[:retire_items] = vms                                # Set the array of retire items
      end
    end
    session[:assigned_filters] = assigned_filters
    if @explorer
      retire
    else
      drop_breadcrumb(:name => _("Retire %{name}") % {:name => rec_cls.to_s.pluralize},
                      :url  => "/#{session[:controller]}/retire")
      render :update do |page|
        page.redirect_to :controller => rec_cls, :action => 'retire'      # redirect to build the retire screen
      end
    end
  end
  alias_method :instance_retire, :retirevms
  alias_method :vm_retire, :retirevms
  alias_method :service_retire, :retirevms
  alias_method :orchestration_stack_retire, :retirevms

  def retirement_info
    case request.parameters[:controller]
    when "orchestration_stack"
      assert_privileges("orchestration_stack_retire")
      kls = OrchestrationStack
    when "service"
      assert_privileges("service_retire")
      kls = Service
    when "vm_cloud", "vm"
      assert_privileges("instance_retire")
      kls = Vm
    when "vm_infra"
      assert_privileges("vm_retire")
      kls = Vm
    end
    obj = kls.find_by_id(params[:id])
    render :json => {
      :retirement_date    => obj.retires_on.try(:strftime, '%m/%d/%Y'),
      :retirement_warning => obj.retirement_warn
    }
  end

  # Build the retire VMs screen
  def retire
    @sb[:explorer] = true if @explorer
    kls = case request.parameters[:controller]
          when "orchestration_stack"
            OrchestrationStack
          when "service"
            Service
          when "vm_infra", "vm_cloud", "vm", "vm_or_template"
            Vm
          end
    if params[:button]
      if params[:button] == "cancel"
        flash = _("Set/remove retirement date was cancelled by the user")
        @sb[:action] = nil
      elsif params[:button] == "save"
        if params[:retire_date].blank?
          t = nil
          w = nil
          if session[:retire_items].length == 1
            flash = _("Retirement date removed")
          else
            flash = _("Retirement dates removed")
          end
        else
          t = "#{params[:retire_date]} 00:00:00 Z"
          w = params[:retire_warn].to_i
          if session[:retire_items].length == 1
            flash = _("Retirement date set to %{date}") % {:date => params[:retire_date]}
          else
            flash = _("Retirement dates set to %{date}") % {:date => params[:retire_date]}
          end
        end
        kls.retire(session[:retire_items], :date => t, :warn => w) # Call the model to retire the VM(s)
        @sb[:action] = nil
      end
      add_flash(flash)
      if @sb[:explorer]
        replace_right_cell
      else
        session[:flash_msgs] = @flash_array.dup
        render :update do |page|
          page.redirect_to previous_breadcrumb_url
        end
      end
      return
    end
    session[:changed] = @changed = false
    drop_breadcrumb(:name => _("Retire %{name}") % {:name => kls.to_s.pluralize},
                    :url  => "/#{session[:controller]}/retire")
    session[:cat] = nil                 # Clear current category
    @retireitems = kls.find(session[:retire_items]).sort_by(&:name) # Get the db records
    build_targets_hash(@retireitems)
    @view = get_db_view(kls)              # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@retireitems, @view.cols + ['id'])
    if @retireitems.length == 1 && !@retireitems[0].retires_on.nil?
      t = @retireitems[0].retires_on                                         # Single VM, set to current time
      w = @retireitems[0].retirement_warn if @retireitems[0].retirement_warn # Single VM, get retirement warn
    else
      t = nil
    end
    session[:retire_date] = t.nil? ? nil : "#{t.month}/#{t.day}/#{t.year}"
    session[:retire_warn] = w
    @in_a_form = true
    @refresh_partial = "shared/views/retire" if @explorer || @layout == "orchestration_stack"
  end

  def vm_right_size
    assert_privileges(params[:pressed])
    # check to see if coming from show_list or drilled into vms from another CI
    rec_cls = "vm"
    recs = params[:display] ? find_checked_items : [params[:id].to_i]
    if recs.length < 1
      add_flash(_("One or more %{model} must be selected to Right-Size Recommendations") %
        {:model => ui_lookup(:table => request.parameters[:controller])}, :error)
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
      return
    else
      if VmOrTemplate.includes_template?(recs)
        add_flash(_("Right-Size Recommendations does not apply to selected %{model}") %
          {:model => ui_lookup(:table => "miq_template")}, :error)
        render_flash_and_scroll
        return
      end
    end
    if @explorer
      @refresh_partial = "vm_common/right_size"
      right_size
      replace_right_cell if @orig_action == "x_history"
    else
      render :update do |page|
        if role_allows(:feature => "vm_right_size")
          page.redirect_to :controller => "#{rec_cls}", :action => 'right_size', :id => recs[0], :escape => false           # redirect to build the ownership screen
        end
      end
    end
  end
  alias_method :instance_right_size, :vm_right_size

  # Assign/unassign ownership to a set of objects
  def reconfigure
    @sb[:explorer] = true if @explorer
    @request_id = nil
    @in_a_form = @reconfigure = true
    drop_breadcrumb(:name => _("Reconfigure"), :url => "/vm_common/reconfigure")
    if params[:rec_ids]
      @reconfigure_items = params[:rec_ids]
    end
    if params[:req_id]
      @request_id = params[:req_id]
    end
    @reconfigitems = Vm.find(@reconfigure_items).sort_by(&:name) # Get the db records
    build_targets_hash(@reconfigitems)
    @force_no_grid_xml   = true
    @view, @pages = get_view(Vm, :view_suffix => "VmReconfigureRequest", :where_clause => ["vms.id IN (?)", @reconfigure_items])  # Get the records (into a view) and the paginator
    get_reconfig_limits
    unless @explorer
      render :action => "show"
    end
  end

  def reconfigure_update
    case params[:button]
    when "cancel"
      add_flash(_("VM Reconfigure Request was cancelled by the user"))
      if @sb[:explorer]
        @sb[:action] = nil
        replace_right_cell
      else
        session[:flash_msgs] = @flash_array
        render :update do |page|
          page.redirect_to(previous_breadcrumb_url)
        end
      end
    when "submit"
      options = {:src_ids => params[:objectIds]}
      if params[:cb_memory] == 'true'
        options[:vm_memory] = params[:memory_type] == "MB" ? params[:memory] : (params[:memory].to_i.zero? ? params[:memory] : params[:memory].to_i * 1024)
      end
      if params[:cb_cpu] == 'true'
        options[:cores_per_socket]  = params[:cores_per_socket_count].nil? ? 1 : params[:cores_per_socket_count].to_i
        options[:number_of_sockets] = params[:socket_count].nil? ? 1 : params[:socket_count].to_i
        vccores = params[:cores_per_socket_count] == 0 ? 1 : params[:cores_per_socket_count]
        vsockets = params[:socket_count] == 0 ? 1 : params[:socket_count]
        options[:number_of_cpus] = vccores.to_i * vsockets.to_i
      end
      if(params[:id] && params[:id] != 'new')
        @request_id = params[:id]
      end
      if VmReconfigureRequest.make_request(@request_id, options, current_user)
        flash = _("VM Reconfigure Request was saved")
        if role_allows(:feature => "miq_request_show_list", :any => true)
          render :update do |page|
            page.redirect_to :controller => 'miq_request', :action => 'show_list', :flash_msg => flash
          end
        else
          url = previous_breadcrumb_url.split('/')
          render :update do |page|
            page.redirect_to :controller => url[1], :action => url[2], :flash_msg => flash
          end
        end
      else
        # TODO - is request ever nil? ??
        add_flash(_("Error adding VM Reconfigure Request"))
      end
      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
        return
      end
    end
  end

  def reconfigure_form_fields
    request_data = ''
    @request_id, request_data = params[:id].split(/\s*,\s*/, 2)
    @reconfigure_items = request_data.split(/\s*,\s*/)
    request_hash = build_reconfigure_hash
    render :json => request_hash
  end

  # edit single selected Object
  def edit_record
    assert_privileges(params[:pressed])
    obj = find_checked_items
    db = params[:db] if params[:db]

    case params[:pressed]
    when "miq_template_edit"
      @redirect_controller = "miq_template"
    when "image_edit", "instance_edit", "vm_edit"
      @redirect_controller = "vm"
    when "host_edit"
      @redirect_controller = "host"
      session[:host_items] = obj if obj.length > 1
    end
    @redirect_id = obj[0] if obj.length == 1      # not redirecting to an id if multi host are selected for credential edit

    if !["ScanItemSet", "Condition", "Schedule", "MiqAeInstance"].include?(db)
      #       page.redirect_to :controller=>params[:rec], :action=>link   # redirect to build the compare screen
      @refresh_partial = "edit"
      @refresh_partial = "edit_set" if params[:db] == "policyprofile"
    else
      if db == "ScanItemSet"
        scan = ScanItemSet.find(obj[0])
        if !scan.read_only
          @refresh_partial = "edit"
        else
          @refresh_partial = "show_list_set"
        end
      elsif db == "Condition"
        cond = Condition.find(obj[0])
        if cond.filename.nil?
          @refresh_partial = "edit"
        else
          @refresh_partial = "show_list"
        end
      elsif db == "Schedule" && params[:controller] != "report"
        sched = MiqSchedule.find(obj[0])
        @refresh_partial = "edit"
      elsif db == "Schedule" && params[:controller] == "report"
        sched = MiqSchedule.find(obj[0])
        @refresh_partial = "schedule_edit"
      elsif db == "MiqAeInstance"
        @refresh_partial = "instance_edit"
      end
    end
  end

  # copy single selected Object
  def copy_record
    obj = find_checked_items
    @refresh_partial = "copy"
    @redirect_id = obj[0]
  end

  # Build the vm detail gtl view
  def show_details(db, options = {})  # Pass in the db, parent vm is in @vm
    association = options[:association]
    conditions  = options[:conditions]
    # generate the grid/tile/list url to come back here when gtl buttons are pressed
    @gtl_url       = "/#{@db}/#{@listicon.pluralize}/#{@record.id}?"
    @showtype      = "details"
    @display       = "main"
    @no_checkboxes = true
    @showlinks     = true

    @view, @pages = get_view(db,
                             :parent      => @record,
                             :association => association,
                             :conditions  => conditions,
                             :dbname      => "#{@db}item")  # Get the records into a view & paginator

    if @explorer # In explorer?
      @refresh_partial = "vm_common/#{@showtype}"
      replace_right_cell
    else
      # Came in from outside, use RJS to redraw gtl partial
      if params[:ppsetting] || params[:entry] || params[:sort_choice]
        replace_gtl_main_div
      else
        render :action => 'show'
      end
    end
  end

  # show a single item from a detail list
  def show_item
    @showtype = "item"
    if @explorer
      @refresh_partial = "layouts/#{@showtype}"
      replace_right_cell
    else
      render :action => 'show'
    end
  end

  def snia_local_file_systems
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db unless @db.nil?
    @db = session[:db] unless session[:db].nil?

    @record = identify_record(params[:id])
    return if record_no_longer_exists?(@record)

    @view = session[:view]                  # Restore the view from the session to get column names for the display
    @display = "snia_local_file_systems"
    if !params[:show].nil?
      @item = SniaLocalFileSystem.find_by_id(from_cid(params[:show]))
      drop_breadcrumb(:name => @record.evm_display_name + " (" + ui_lookup(:tables => "snia_local_file_system") + ")", :url => "/#{@db}/snia_local_file_systems/#{@record.id}?page=#{@current_page}")
      drop_breadcrumb(:name => @item.evm_display_name, :url => "/#{@db}/show/#{@record.id}?show=#{@item.id}")
      show_item
    else
      drop_breadcrumb(:name => @record.evm_display_name + " (" + ui_lookup(:tables => "snia_local_file_system") + ")", :url => "/#{@db}/snia_local_file_systems/#{@record.id}")
      # generate the grid/tile/list url to come back here when gtl buttons are pressed
      @gtl_url = "/#{@db}/snia_local_file_systems/" + @record.id.to_s + "?"
      @showtype = "details"

      table_name = "snia_local_file_systems"
      model_name = table_name.classify.constantize
      drop_breadcrumb(:name => @record.evm_display_name + " (All #{ui_lookup(:tables => @display.singularize)})", :url => "/#{self.class.table_name}/show/#{@record.id}?display=#{@display}")
      @view, @pages = get_view(model_name, :parent => @record, :parent_method => :local_file_systems)  # Get the records (into a view) and the paginator
      render :action => 'show'
    end
  end

  def cim_base_storage_extents
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db unless @db.nil?
    @db = session[:db] unless session[:db].nil?

    @record = identify_record(params[:id])
    return if record_no_longer_exists?(@record)

    @view = session[:view]                  # Restore the view from the session to get column names for the display
    @display = "cim_base_storage_extents"
    if !params[:show].nil?
      @item = CimBaseStorageExtent.find_by_id(from_cid(params[:show]))
      drop_breadcrumb(:name => @record.evm_display_name + " (" + ui_lookup(:tables => "cim_base_storage_extent") + ")", :url => "/#{@db}/cim_base_storage_extents/#{@record.id}?page=#{@current_page}")
      drop_breadcrumb(:name => @item.evm_display_name, :url => "/#{@db}/show/#{@record.id}?show=#{@item.id}")
      show_item
    else
      drop_breadcrumb(:name => @record.evm_display_name + " (" + ui_lookup(:tables => "cim_base_storage_extent") + ")", :url => "/#{@db}/cim_base_storage_extents/#{@record.id}")
      # generate the grid/tile/list url to come back here when gtl buttons are pressed
      @gtl_url = "/#{@db}/cim_base_storage_extents/" + @record.id.to_s + "?"
      @showtype = "details"

      table_name = "cim_base_storage_extents"
      model_name = table_name.classify.constantize
      drop_breadcrumb(:name => _("%{name} (All ${tables})") % {:name   => @record.evm_display_name,
                                                               :tables => ui_lookup(:tables => @display.singularize)},
                      :url  => "/#{self.class.table_name}/show/#{@record.id}?display=#{@display}")
      @view, @pages = get_view(model_name, :parent => @record, :parent_method => :base_storage_extents)  # Get the records (into a view) and the paginator
      render :action => 'show'
    end
  end

  def get_record(db)
    if db == "host"
      @host = @record = identify_record(params[:id], Host)
    elsif db == "miq_template"
      @miq_template = @record = identify_record(params[:id], MiqTemplate)
    elsif ["vm_infra", "vm_cloud", "vm", "vm_or_template"].include?(db)
      @vm = @record = identify_record(params[:id], VmOrTemplate)
    end
  end

  def guest_applications
    @explorer = true if request.xml_http_request? # Ajax request means in explorer
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db unless @db.nil?
    @db = session[:db] unless session[:db].nil?
    get_record(@db)
    @sb[:action] = params[:action]
    return if record_no_longer_exists?(@record)

    @lastaction = "guest_applications"
    if !params[:show].nil? || !params[:x_show].nil?
      id = params[:show] ? params[:show] : params[:x_show]
      @item = @record.guest_applications.find(from_cid(id))
      if Regexp.new(/linux/).match(@record.os_image_name.downcase)
        drop_breadcrumb(:name => _("%{name} (Packages)") % {:name => @record.name},
                        :url  => "/#{@db}/guest_applications/#{@record.id}?page=#{@current_page}")
      else
        drop_breadcrumb(:name => _("%{name} (Applications)") % {:name => @record.name},
                        :url  => "/#{@db}/guest_applications/#{@record.id}?page=#{@current_page}")
      end
      drop_breadcrumb(:name => @item.name, :url => "/#{@db}/show/#{@record.id}?show=#{@item.id}")
      @view = get_db_view(GuestApplication)         # Instantiate the MIQ Report view object
      show_item
    else
      drop_breadcrumb({:name => @record.name, :url => "/#{@db}/show/#{@record.id}"}, true)
      if Regexp.new(/linux/).match(@record.os_image_name.downcase)
        drop_breadcrumb(:name => _("%{name} (Packages)") % {:name => @record.name},
                        :url  => "/#{@db}/guest_applications/#{@record.id}")
      else
        drop_breadcrumb(:name => _("%{name} (Applications)") % {:name => @record.name},
                        :url  => "/#{@db}/guest_applications/#{@record.id}")
      end
      @listicon = "guest_application"
      show_details(GuestApplication)
    end
  end

  def patches
    @explorer = true if request.xml_http_request? # Ajax request means in explorer
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db unless @db.nil?
    @db = session[:db] unless session[:db].nil?
    get_record(@db)
    @sb[:action] = params[:action]
    return if record_no_longer_exists?(@record)

    @lastaction = "patches"
    if !params[:show].nil? || !params[:x_show].nil?
      id = params[:show] ? params[:show] : params[:x_show]
      @item = @record.patches.find(from_cid(id))
      drop_breadcrumb(:name => _("%{name} (Patches)") % {:name => @record.name},
                      :url  => "/#{@db}/patches/#{@record.id}?page=#{@current_page}")
      drop_breadcrumb(:name => @item.name, :url => "/#{@db}/patches/#{@record.id}?show=#{@item.id}")
      @view = get_db_view(Patch)
      show_item
    else
      drop_breadcrumb(:name => _("%{name} (Patches)") % {:name => @record.name},
                      :url  => "/#{@db}/patches/#{@record.id}")
      @listicon = "patch"
      show_details(Patch)
    end
  end

  def groups
    @explorer = true if request.xml_http_request? && explorer_controller? # Ajax request means in explorer
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db unless @db.nil?
    @db = session[:db] unless session[:db].nil?
    get_record(@db)
    @sb[:action] = params[:action]
    return if record_no_longer_exists?(@record)

    @lastaction = "groups"
    if !params[:show].nil? || !params[:x_show].nil?
      id = params[:show] ? params[:show] : params[:x_show]
      @item = @record.groups.find(from_cid(id))
      drop_breadcrumb(:name => _("%{name} (Groups)") % {:name => @record.name},
                      :url  => "/#{@db}/groups/#{@record.id}?page=#{@current_page}")
      drop_breadcrumb({:name => @item.name, :url => "/#{@db}/groups/#{@record.id}?show=#{@item.id}"})
      @user_names = @item.users
      @view = get_db_view(Account, :association => "groups")
      show_item
    else
      drop_breadcrumb(:name => _("%{name} (Groups)") % {:name => @record.name},
                      :url  => "/#{@db}/groups/#{@record.id}")
      @listicon = "group"
      show_details(Account, :association => "groups")
    end
  end

  def users
    @explorer = true if request.xml_http_request? && explorer_controller? # Ajax request means in explorer
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db unless @db.nil?
    @db = session[:db] unless session[:db].nil?
    get_record(@db)
    @sb[:action] = params[:action]
    return if record_no_longer_exists?(@record)

    @lastaction = "users"
    if !params[:show].nil? || !params[:x_show].nil?
      id = params[:show] ? params[:show] : params[:x_show]
      @item = @record.users.find(from_cid(id))
      drop_breadcrumb(:name => _("%{name} (Users)") % {:name => @record.name},
                      :url  => "/#{@db}/users/#{@record.id}?page=#{@current_page}")
      drop_breadcrumb(:name => @item.name, :url => "/#{@db}/show/#{@record.id}?show=#{@item.id}")
      @group_names = @item.groups
      @view = get_db_view(Account, :association => "users")
      show_item
    else
      drop_breadcrumb(:name => _("%{name} (Users)") % {:name => @record.name},
                      :url  => "/#{@db}/users/#{@record.id}")
      @listicon = "user"
      show_details(Account, :association => "users")
    end
  end

  # Discover hosts
  def discover
    assert_privileges("#{controller_name}_discover")
    session[:type] = params[:discover_type] if params[:discover_type]
    title = set_discover_title(session[:type], request.parameters[:controller])
    if params["cancel"]
      redirect_to :action    => 'show_list',
                  :flash_msg => _("%{title} Discovery was cancelled by the user") % {:title => title}
    end
    @userid = ""
    @password = ""
    @verify = ""
    @client_id = ""
    @client_key = ""
    @azure_tenant_id = ""
    if session[:type] == "hosts"
      @discover_type = Host.host_discovery_types
    elsif session[:type] == "ems"
      if request.parameters[:controller] == 'ems_infra'
        @discover_type = ExtManagementSystem.ems_infra_discovery_types
      else
        @discover_type = ExtManagementSystem.ems_cloud_discovery_types.invert.collect do |type|
          [discover_type(type[0]), type[1]]
        end
        @discover_type_selected = @discover_type.first.try!(:last)
      end
    else
      @discover_type = ExtManagementSystem.ems_infra_discovery_types
    end
    discover_type = []
    @discover_type_checked = []        # to keep track of checked items when start button is pressed
    @discover_type_selected = nil
    if params["start"]
      audit = {:event => "ms_and_host_discovery", :target_class => "Host", :userid => session[:userid]}
      if request.parameters[:controller] != "ems_cloud"
        from_ip = params[:from_first].to_s + "." + params[:from_second].to_s + "." + params[:from_third].to_s + "." + params[:from_fourth]
        to_ip = params[:from_first].to_s + "." + params[:from_second].to_s + "." + params[:from_third].to_s + "." + params[:to_fourth]

        i = 0
        while i < @discover_type.length
          if @discover_type.length == 1
            discover_type.push(@discover_type[i].to_sym)
            @discover_type_checked.push(@discover_type[i])
          else
            if params["discover_type_#{@discover_type[i]}"]
              discover_type.push(@discover_type[i].to_sym)
              @discover_type_checked.push(@discover_type[i])
            end
          end
          i += 1
        end

        @from = {}
        @from[:first] = params[:from_first]
        @from[:second] = params[:from_second]
        @from[:third] = params[:from_third]
        @from[:fourth] = params[:from_fourth]
        @to = {}
        @to[:first] = params[:from_first]
        @to[:second] = params[:from_second]
        @to[:third] = params[:from_third]
        @to[:fourth] = params[:to_fourth]
      end
      @in_a_form = true
      drop_breadcrumb(:name => _("%{title} Discovery") % {:title => title}, :url => "/host/discover")
      @discover_type_selected = params[:discover_type_selected]

      if request.parameters[:controller] == "ems_cloud" && params[:discover_type_selected] == ExtManagementSystem.ems_cloud_discovery_types['azure']
        @client_id = params[:client_id] if params[:client_id]
        @client_key = params[:client_key] if params[:client_key]
        @azure_tenant_id = params[:azure_tenant_id] if params[:azure_tenant_id]

        if @client_id == "" || @client_key == "" || @azure_tenant_id == ""
          add_flash(_("Client ID, Client Key and Azure Tenant ID are required"), :error)
          render :action => 'discover'
          return
        end
      elsif request.parameters[:controller] == "ems_cloud" || params[:discover_type_ipmi].to_s == "1"
        @userid = params[:userid] if  params[:userid]
        @password = params[:password] if params[:password]
        @verify = params[:verify] if params[:verify]
        if request.parameters[:controller] == "ems_cloud" && params[:userid] == ""
          add_flash(_("Username is required"), :error)
          render :action => 'discover'
          return
        end
        if params[:userid] == "" && params[:password] != ""
          add_flash(_("Username must be entered if Password is entered"), :error)
          render :action => 'discover'
          return
        end
        if params[:password] != params[:verify]
          add_flash(_("Password/Verify Password do not match"), :error)
          render :action => 'discover'
          return
        end
      end

      if request.parameters[:controller] != "ems_cloud" && discover_type.length <= 0
        add_flash(_("At least 1 item must be selected for discovery"), :error)
        render :action => 'discover'
      else
        begin
          if request.parameters[:controller] != "ems_cloud"
            if params[:discover_type_ipmi].to_s == "1"
              options = {:discover_types => discover_type, :credentials => {:ipmi => {:userid => @userid, :password => @password}}}
            else
              options = {:discover_types => discover_type}
            end
            Host.discoverByIpRange(from_ip, to_ip, options)
          else
            if params[:discover_type_selected] == ExtManagementSystem.ems_cloud_discovery_types['azure']
              ManageIQ::Providers::Azure::CloudManager.discover_queue(@client_id, @client_key, @azure_tenant_id)
            else
              ManageIQ::Providers::Amazon::CloudManager.discover_queue(@userid, @password)
            end
          end
        rescue => err
          #       @flash_msg = "'Host Discovery' returned: " + err.message; @flash_error = true
          add_flash(_("%{title} Discovery returned: %{error_message}") %
            {:title => title, :error_message => err.message}, :error)
          render :action => 'discover'
          return
        else
          AuditEvent.success(audit.merge(:message => "#{title} discovery initiated (from_ip:[#{from_ip}], to_ip:[#{to_ip}])"))
          redirect_to :action    => 'show_list',
                      :flash_msg => _("%{model}: Discovery successfully initiated") % {:model => title}
        end
      end
    end
    # Fell through, must be first time
    @in_a_form = true
    @title = _("%{title} Discovery") % {:title => title}
    @from = {:first => "", :second => "", :third => "", :fourth => ""}
    @to = {:first => "", :second => "", :third => "", :fourth => ""}
  end

  def set_discover_title(type, controller)
    if type == "hosts"
      return _("Hosts / Nodes")
    else
      return ui_lookup(:tables => controller)
    end
  end

  # AJAX driven routine to check for changes in ANY field on the discover form
  def discover_field_changed
    render :update do |page|                    # Use JS to update the display
      if params[:from_first]
        # params[:from][:first] =~ /[a-zA-Z]/
        if params[:from_first] =~ /[\D]/
          temp = params[:from_first].gsub(/[\.]/, "")
          field_shift = true if params[:from_first] =~ /[\.]/ && params[:from_first].gsub(/[\.]/, "") =~ /[0-9]/ && temp.gsub!(/[\D]/, "").nil?
          page << "$('#from_first').val('#{j_str(params[:from_first]).gsub(/[\D]/, "")}');"
          page << javascript_focus('from_second') if field_shift
        else
          page << "$('#to_first').val('#{j_str(params[:from_first])}');"
          page << javascript_focus('from_second') if params[:from_first].length == 3
        end
      elsif params[:from_second]
        if params[:from_second] =~ /[\D]/
          temp = params[:from_second].gsub(/[\.]/, "")
          field_shift = true if params[:from_second] =~ /[\.]/ && params[:from_second].gsub(/[\.]/, "") =~ /[0-9]/ && temp.gsub!(/[\D]/, "").nil?
          page << "$('#from_second').val('#{j_str(params[:from_second].gsub(/[\D]/, ""))}');"
          page << javascript_focus('from_third') if field_shift
        else
          page << "$('#to_second').val('#{j_str(params[:from_second])}');"
          page << javascript_focus('from_third') if params[:from_second].length == 3
        end
      elsif params[:from_third]
        if params[:from_third] =~ /[\D]/
          temp = params[:from_third].gsub(/[\.]/, "")
          field_shift = true if params[:from_third] =~ /[\.]/ && params[:from_third].gsub(/[\.]/, "") =~ /[0-9]/ && temp.gsub!(/[\D]/, "").nil?
          page << "$('#from_third').val('#{j_str(params[:from_third].gsub(/[\D]/, ""))}');"
          page << javascript_focus('from_fourth') if field_shift
        else
          page << "$('#to_third').val('#{j_str(params[:from_third])}');"
          page << javascript_focus('from_fourth') if params[:from_third].length == 3
        end
      elsif params[:from_fourth] && params[:from_fourth] =~ /[\D]/
        page << "$('#from_fourth').val('#{j_str(params[:from_fourth].gsub(/[\D]/, ""))}');"
      elsif params[:to_fourth] && params[:to_fourth] =~ /[\D]/
        page << "$('#to_fourth').val('#{j_str(params[:to_fourth].gsub(/[\D]/, ""))}');"
      end
      if (request.parameters[:controller] == "ems_cloud" && params[:discover_type_selected]) || (params[:discover_type_ipmi] && params[:discover_type_ipmi].to_s == "1")
        if params[:discover_type_selected] && params[:discover_type_selected] == 'azure'
          page << javascript_hide("discover_credentials")
          page << javascript_show("discover_azure_credentials")
        elsif params[:discover_type_selected] && params[:discover_type_selected] == 'amazon'
          page << javascript_hide("discover_azure_credentials")
          page << javascript_show("discover_credentials")
        else
          @ipmi = true
          page << javascript_show("discover_credentials")
        end
      elsif params[:discover_type_ipmi] && params[:discover_type_ipmi].to_s == "null"
        @ipmi = false
        page << javascript_hide("discover_credentials")
      elsif @ipmi == false
        page << javascript_hide("discover_credentials")
      end
    end
  end

  def process_elements(elements, klass, task, display_name = nil, order_field = nil)
    ['name', 'description', 'title'].each { |key| order_field ||= key if klass.column_names.include?(key) }

    klass.where(:id => elements).order(order_field == "ems_id" ? order_field : "lower(#{order_field})").each do |elem|
      id          = elem.id
      description = get_record_display_name(elem)
      name        = elem.send(order_field.to_sym)
      if task == "destroy"
        process_element_destroy(elem, klass, name)
      else
        model_name = ui_lookup(:model => klass.name) # Lookup friendly model name in dictionary
        begin
          elem.send(task.to_sym) if elem.respond_to?(task) # Run the task
        rescue => bang
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': %{error_msg}") %
                   {:model => model_name, :name => record_name, :task => (display_name || task),
                    :error_msg => bang.message}, :error)
        else
          add_flash(_("%{model} \"%{name}\": %{task} successfully initiated") %
                   {:model => model_name, :name => description, :task => (display_name || task)})
        end
      end
    end
  end

  private ############################

  def process_element_destroy(element, klass, name)
    return unless element.respond_to?(:destroy)

    audit = {:event        => "#{klass.name.downcase}_record_delete",
             :message      => "[#{name}] Record deleted",
             :target_id    => element.id,
             :target_class => klass.base_class.name,
             :userid       => session[:userid]}

    model_name  = ui_lookup(:model => klass.name) # Lookup friendly model name in dictionary
    record_name = get_record_display_name(element)

    begin
      element.destroy
    rescue => bang
      add_flash(_("%{model} \"%{name}\": Error during delete: %{error_msg}") %
               {:model => model_name, :name => record_name, :error_msg => bang.message}, :error)
    else
      if element.destroyed?
        AuditEvent.success(audit)
        add_flash(_("%{model} \"%{name}\": Delete successful") % {:model => model_name, :name => record_name})
      else
        error_msg = element.errors.collect { |_attr, msg| msg }.join(';')
        add_flash(_("%{model} \"%{name}\": Error during delete: %{error_msg}") %
                 {:model => model_name, :name => record_name, :error_msg => error_msg}, :error)
      end
    end
  end

  # find the record that was chosen
  def identify_record(id, klass = self.class.model)
    begin
      record = find_by_id_filtered(klass, from_cid(id))
    rescue ActiveRecord::RecordNotFound
    rescue => @bang
      if @explorer
        self.x_node = "root"
        add_flash(@bang.message, :error, true)
        session[:flash_msgs] = @flash_array.dup
      end
    end
    record
  end

  def process_show_list(options = {})
    session["#{self.class.session_key_prefix}_display".to_sym] = nil
    @display  = nil
    @lastaction  = "show_list"
    @gtl_url = "/show_list"

    model = options.delete(:model) # Get passed in model override
    @view, @pages = get_view(model || self.class.model, options)  # Get the records (into a view) and the paginator
    if session[:bc] && session[:menu_click]               # See if we came from a perf chart menu click
      drop_breadcrumb(:name => session[:bc],
                      :url  => url_for(:controller    => self.class.table_name,
                                       :action        => "show_list",
                                       :bc            => session[:bc],
                                       :sb_controller => params[:sb_controller],
                                       :menu_click    => session[:menu_click],
                                       :escape        => false))
    else
      @breadcrumbs = []
      bc_name = breadcrumb_name(model)
      bc_name += " - " + session["#{self.class.session_key_prefix}_type".to_sym].titleize if session["#{self.class.session_key_prefix}_type".to_sym]
      bc_name += " (filtered)" if @filters && (!@filters[:tags].blank? || !@filters[:cats].blank?)
      action = %w(container service vm_cloud vm_infra vm_or_template).include?(self.class.table_name) ? "explorer" : "show_list"
      @breadcrumbs.clear
      drop_breadcrumb(:name => bc_name, :url => "/#{self.class.table_name}/#{action}")
    end
    @layout = session["#{self.class.session_key_prefix}_type".to_sym] if session["#{self.class.session_key_prefix}_type".to_sym]
    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    build_listnav_search_list(@view.db) if !["miq_task"].include?(@layout) && !session[:menu_click]
    # Came in from outside show_list partial
    unless params[:action] == "explorer"
      if params[:action] != "button" && (params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice])
        replace_gtl_main_div
      end
    end
  end

  def breadcrumb_name(_model)
    ui_lookup(:models => self.class.model.name)
  end

  # Reconfigure selected VMs
  def reconfigurevms
    assert_privileges(params[:pressed])
    @request_id = nil
    # check to see if coming from show_list or drilled into vms from another CI
    rec_cls = "vm"
    recs = []
    # if coming in to edit from miq_request list view
    if !session[:checked_items].nil? && (@lastaction == "set_checked_items" || params[:pressed] == "miq_request_edit")
      @request_id = params[:id]
      recs = session[:checked_items]
    elsif !params[:id] || params[:pressed] == 'vm_reconfigure'
      recs = find_checked_items
    end
    if recs.blank?
      recs = [params[:id].to_i]
    end
    if recs.length < 1
      add_flash(_("One or more %{model} must be selected to Reconfigure") %
        {:model => Dictionary.gettext(db.to_s, :type => :model, :notfound => :titleize, :plural => true)}, :error)
      render_flash_and_scroll
      return
    else
      if VmOrTemplate.includes_template?(recs)
        add_flash(_("Reconfigure does not apply because you selected at least one %{model}") %
          {:model => ui_lookup(:table => "miq_template")}, :error)
        render_flash_and_scroll
        return
      end
      unless VmOrTemplate.reconfigurable?(recs)
        add_flash(_("Reconfigure does not apply because you selected at least one un-reconfigurable VM"), :error)
        render_flash_and_scroll
        return
      end
      @reconfigure_items = recs.collect(&:to_i)
    end
    if @explorer
      reconfigure
      session[:changed] = true  # need to enable submit button when screen loads
      @refresh_partial = "vm_common/reconfigure"
    else
      render :update do |page|
        if role_allows(:feature => "vm_reconfigure")
          page.redirect_to :controller => "#{rec_cls}", :action => 'reconfigure', :req_id => @request_id, :rec_ids => @reconfigure_items, :escape => false         # redirect to build the ownership screen
        end
      end
    end
  end
  alias_method :image_reconfigure, :reconfigurevms
  alias_method :instance_reconfigure, :reconfigurevms
  alias_method :vm_reconfigure, :reconfigurevms
  alias_method :miq_template_reconfigure, :reconfigurevms

  def get_reconfig_info
    @reconfigureitems = Vm.find(@reconfigure_items).sort_by(&:name)
    # set memory to nil if multiple items were selected with different mem_cpu values
    memory = @reconfigureitems.first.mem_cpu
    memory = nil unless @reconfigureitems.all? { |vm| vm.mem_cpu == memory }

    socket_count = @reconfigureitems.first.num_cpu
    socket_count = '' unless @reconfigureitems.all? { |vm| vm.num_cpu == socket_count }

    cores_per_socket = @reconfigureitems.first.cpu_cores_per_socket
    cores_per_socket = '' unless @reconfigureitems.all? { |vm| vm.cpu_cores_per_socket == cores_per_socket }
    memory, memory_type = reconfigure_calculations(memory)

    { :objectIds => @reconfigure_items, :memory => memory, :memory_type => memory_type, :socket_count => socket_count.to_s, :cores_per_socket_count =>cores_per_socket.to_s}
  end

  def get_reconfig_limits
    @reconfig_limits = VmReconfigureRequest.request_limits(:src_ids => @reconfigure_items)
    mem1, fmt1 = reconfigure_calculations(@reconfig_limits[:min__vm_memory])
    mem2, fmt2 = reconfigure_calculations(@reconfig_limits[:max__vm_memory])
    @reconfig_memory_note = "Between #{mem1}#{fmt1} and #{mem2}#{fmt2}"

    @socket_options = []
    @reconfig_limits[:max__number_of_sockets].times do |tidx|
      idx = tidx + @reconfig_limits[:min__number_of_sockets]
      @socket_options.push(idx) if idx <= @reconfig_limits[:max__number_of_sockets]
    end

    @cores_options = []
    @reconfig_limits[:max__cores_per_socket].times do |tidx|
      idx = tidx + @reconfig_limits[:min__cores_per_socket]
      @cores_options.push(idx) if idx <= @reconfig_limits[:max__cores_per_socket]
    end
  end

  # Build the reconfigure data hash
  def build_reconfigure_hash
    @req = nil
    @reconfig_values = {}
    if @request_id == 'new'
      @reconfig_values = get_reconfig_info
    else
      @req = MiqRequest.find_by_id(@request_id)
      @reconfig_values[:src_ids] = @req.options[:src_ids]
      @reconfig_values[:memory], @reconfig_values[:memory_type] = @req.options[:vm_memory] ? reconfigure_calculations(@req.options[:vm_memory]) : ['','']
      @reconfig_values[:cores_per_socket_count] = @req.options[:cores_per_socket] ? @req.options[:cores_per_socket].to_s : ''
      @reconfig_values[:socket_count] = @req.options[:number_of_sockets] ? @req.options[:number_of_sockets].to_s : ''
    end

    @reconfig_values[:cb_memory] = @req && @req.options[:vm_memory] ? true : false       # default for checkbox is false for new request
    @reconfig_values[:cb_cpu] =  @req && ( @req.options[:number_of_sockets] || @req.options[:cores_per_socket]) ? true : false     # default for checkbox is false for new request
    @reconfig_values
  end

  def reconfigure_calculations(memory)
    if memory.to_i > 1024 && memory.to_i % 1024 == 0
      mem = memory.to_i / 1024
      fmt = "GB"
    else
      mem = memory
      fmt = "MB"
    end
    return mem.to_s, fmt
  end

  # Common VM button handler routines
  def vm_button_operation(method, display_name, partial_after_single_selection = nil)
    vms = []

    # Either a list or coming from a different controller (eg from host screen, go to its vms)
    if @lastaction == "show_list" ||
       !%w(orchestration_stack service vm_cloud vm_infra vm miq_template vm_or_template).include?(
         request.parameters["controller"]) # showing a list

      vms = find_checked_items
      if method == 'retire_now' && VmOrTemplate.includes_template?(vms)
        add_flash(_("Retire does not apply to selected %{model}") %
          {:model => ui_lookup(:table => "miq_template")}, :error)
        render_flash_and_scroll
        return
      end

      if method == 'scan' && !VmOrTemplate.batch_operation_supported?('smartstate_analysis', vms)
        render_flash_not_applicable_to_model('Smartstate Analysis', ui_lookup(:tables => "vm_or_template"))
        return
      end

      if vms.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:tables => request.parameters["controller"]), :task => display_name}, :error)
      else
        process_objects(vms, method)
      end

      if @lastaction == "show_list" # In vm controller, refresh show_list, else let the other controller handle it
        show_list unless @explorer
        @refresh_partial = "layouts/gtl"
      end

    else # showing 1 vm
      klass = get_rec_cls
      if params[:id].nil? || klass.find_by_id(params[:id]).nil?
        add_flash(_("%{record} no longer exists") %
          {:record => ui_lookup(:table => request.parameters["controller"])}, :error)
        show_list unless @explorer
        @refresh_partial = "layouts/gtl"
      else
        vms.push(params[:id])
        process_objects(vms, method) unless vms.empty?

        # TODO: tells callers to go back to show_list because this VM may be gone
        # Should be refactored into calling show_list right here
        if method == 'destroy'
          @single_delete = true unless flash_errors?
        end

        # For Snapshot Trees
        if partial_after_single_selection && !@explorer
          show
          @refresh_partial = partial_after_single_selection
        end
      end
    end

    vms.count
  end

  def get_rec_cls
    case request.parameters["controller"]
    when "miq_template"
      return MiqTemplate
    when "orchestration_stack"
      return OrchestrationStack
    when "service"
      return Service
    else
      return VmOrTemplate
    end
  end

  def process_objects(objs, task, display_name = nil)
    case get_rec_cls.to_s
    when "OrchestrationStack"
      objs, _objs_out_reg = filter_ids_in_region(objs, "OrchestrationStack")
      klass = OrchestrationStack
    when "Service"
      objs, _objs_out_reg = filter_ids_in_region(objs, "Service")
      klass = Service
    when "VmOrTemplate"
      objs, _objs_out_reg = filter_ids_in_region(objs, "VM") unless VmOrTemplate::POWER_OPS.include?(task)
      klass = Vm
    end

    return if objs.empty?

    options = {:ids => objs, :task => task, :userid => session[:userid]}
    options[:snap_selected] = session[:snap_selected] if task == "remove_snapshot" || task == "revert_to_snapshot"
    klass.process_tasks(options)
  rescue => err
    add_flash(_("Error during '%{task}': %{error_message}") % {:task => task, :error_message => err.message}, :error)
  else
    add_flash(_("%{task} initiated for %{model} from the CFME Database") %
      {:task  => display_name ? display_name.titleize : task_name(task),
       :model => pluralize(objs.length, ui_lookup(:model => klass.to_s))})
  end

  def foreman_button_operation(method, display_name)
    items = []
    if params[:id]
      if params[:id].nil? || !ExtManagementSystem.where(:id => params[:id]).exists?
        add_flash(_("%{record} no longer exists") % {:record => ui_lookup(:table => controller_name)}, :error)
      else
        items.push(params[:id])
        @single_delete = true if method == 'destroy' && !flash_errors?
      end
    else
      items = find_checked_items
      if items.empty?
        add_flash(_("No providers were selected for %{task}") % {:task  => display_name}, :error)
      else
        process_cfgmgr(items, method) unless items.empty? && !flash_errors?
      end
    end
  end

  def process_cfgmgr(providers, task)
    providers, _services_out_region = filter_ids_in_region(providers, "ManageIQ::Providers::ConfigurationManager")
    return if providers.empty?

    options = {:ids => providers, :task => task, :userid => session[:userid]}
    kls = ManageIQ::Providers::ConfigurationManager.find_by_id(providers.first).class
    kls.process_tasks(options)
  rescue => err
    add_flash(_("Error during '%{task}': %{message}") % {:task => task, :message => err.message}, :error)
  else
    add_flash(_("%{task} initiated for %{count_model} (%{controller})") %
                {:task        => task_name(task),
                 :controller  => ProviderForemanController.model_to_name(kls.to_s),
                 :count_model => pluralize(providers.length, _("provider"))})
  end

  # Delete all selected or single displayed VM(s)
  def deletevms
    assert_privileges(params[:pressed])
    vm_button_operation('destroy', 'deletion')
  end
  alias_method :image_delete, :deletevms
  alias_method :instance_delete, :deletevms
  alias_method :vm_delete, :deletevms
  alias_method :miq_template_delete, :deletevms

  # Import info for all selected or single displayed vm(s)
  def syncvms
    assert_privileges(params[:pressed])
    vm_button_operation('sync', 'for Virtual Black Box synchronization')
  end

  DEFAULT_PRIVILEGE = Object.new # :nodoc:

  # Refresh the power states for selected or single VMs
  def refreshvms(privilege = DEFAULT_PRIVILEGE)
    if privilege == DEFAULT_PRIVILEGE
      ActiveSupport::Deprecation.warn(<<-MSG.strip_heredoc)
      Please pass the privilege you want to check for when refreshing
      MSG
      privilege = params[:pressed]
    end
    assert_privileges(privilege)
    vm_button_operation('refresh_ems', 'Refresh')
  end
  alias_method :image_refresh, :refreshvms
  alias_method :instance_refresh, :refreshvms
  alias_method :vm_refresh, :refreshvms
  alias_method :miq_template_refresh, :refreshvms

  # Import info for all selected or single displayed vm(s)
  def scanvms
    assert_privileges(params[:pressed])
    vm_button_operation('scan', 'SmartState Analysis')
  end
  alias_method :image_scan, :scanvms
  alias_method :instance_scan, :scanvms
  alias_method :vm_scan, :scanvms
  alias_method :miq_template_scan, :scanvms

  # Immediately retire VMs
  def retirevms_now
    assert_privileges(params[:pressed])
    vm_button_operation('retire_now', 'retire')
  end
  alias_method :instance_retire_now, :retirevms_now
  alias_method :vm_retire_now, :retirevms_now
  alias_method :service_retire_now, :retirevms_now
  alias_method :orchestration_stack_retire_now, :retirevms_now

  def check_compliance_vms
    assert_privileges(params[:pressed])
    vm_button_operation('check_compliance_queue', 'check compliance')
  end
  alias_method :image_check_compliance, :check_compliance_vms
  alias_method :instance_check_compliance, :check_compliance_vms
  alias_method :vm_check_compliance, :check_compliance_vms
  alias_method :miq_template_check_compliance, :check_compliance_vms

  # Collect running processes for all selected or single displayed vm(s)
  def getprocessesvms
    assert_privileges(params[:pressed])
    vm_button_operation('collect_running_processes', 'Collect Running Processes')
  end
  alias_method :instance_collect_running_processes, :getprocessesvms
  alias_method :vm_collect_running_processes, :getprocessesvms

  # Start all selected or single displayed vm(s)
  def startvms
    assert_privileges(params[:pressed])
    vm_button_operation('start', 'start')
  end
  alias_method :instance_start, :startvms
  alias_method :vm_start, :startvms

  # Suspend all selected or single displayed vm(s)
  def suspendvms
    assert_privileges(params[:pressed])
    vm_button_operation('suspend', 'suspend')
  end
  alias_method :instance_suspend, :suspendvms
  alias_method :vm_suspend, :suspendvms

  # Pause all selected or single displayed vm(s)
  def pausevms
    assert_privileges(params[:pressed])
    vm_button_operation('pause', 'pause')
  end
  alias_method :instance_pause, :pausevms
  alias_method :vm_pause, :pausevms

  # Terminate all selected or single displayed vm(s)
  def terminatevms
    assert_privileges(params[:pressed])
    vm_button_operation('vm_destroy', 'terminate')
  end
  alias_method :instance_terminate, :terminatevms

  # Stop all selected or single displayed vm(s)
  def stopvms
    assert_privileges(params[:pressed])
    vm_button_operation('stop', 'stop')
  end
  alias_method :instance_stop, :stopvms
  alias_method :vm_stop, :stopvms

  # Shelve all selected or single displayed vm(s)
  def shelvevms
    assert_privileges(params[:pressed])
    vm_button_operation('shelve', 'shelve')
  end
  alias_method :instance_shelve, :shelvevms
  alias_method :vm_shelve, :shelvevms

  # Shelve all selected or single displayed vm(s)
  def shelveoffloadvms
    assert_privileges(params[:pressed])
    vm_button_operation('shelve_offload', 'shelve_offload')
  end
  alias_method :instance_shelve_offload, :shelveoffloadvms
  alias_method :vm_shelve_offload, :shelveoffloadvms

  # Reset all selected or single displayed vm(s)
  def resetvms
    assert_privileges(params[:pressed])
    vm_button_operation('reset', 'reset')
  end
  alias_method :instance_reset, :resetvms
  alias_method :vm_reset, :resetvms

  # Shutdown guests on all selected or single displayed vm(s)
  def guestshutdown
    assert_privileges(params[:pressed])
    vm_button_operation('shutdown_guest', 'shutdown')
  end
  alias_method :instance_guest_shutdown, :guestshutdown
  alias_method :vm_guest_shutdown, :guestshutdown

  # Standby guests on all selected or single displayed vm(s)
  def gueststandby
    assert_privileges(params[:pressed])
    vm_button_operation('standby_guest', 'standby')
  end

  # Restart guests on all selected or single displayed vm(s)
  def guestreboot
    assert_privileges(params[:pressed])
    vm_button_operation('reboot_guest', 'restart')
  end
  alias_method :instance_guest_restart, :guestreboot
  alias_method :vm_guest_restart, :guestreboot

  # Delete all snapshots for vm(s)
  def deleteallsnapsvms
    assert_privileges(params[:pressed])
    vm_button_operation('remove_all_snapshots', 'delete all snapshots', 'vm_common/config')
  end
  alias_method :vm_snapshot_delete_all, :deleteallsnapsvms

  # Delete selected snapshot for vm
  def deletesnapsvms
    assert_privileges(params[:pressed])
    vm_button_operation('remove_snapshot', 'delete snapshot', 'vm_common/config')
  end
  alias_method :vm_snapshot_delete, :deletesnapsvms

  # Delete selected snapshot for vm
  def revertsnapsvms
    assert_privileges(params[:pressed])
    vm_button_operation('revert_to_snapshot', 'revert to a snapshot', 'vm_common/config')
  end
  alias_method :vm_snapshot_revert, :revertsnapsvms

  # Policy simulation for selected VMs
  def polsimvms
    assert_privileges(params[:pressed])
    vms = find_checked_items
    if vms.blank?
      vms = [params[:id]]
    end
    if vms.length < 1
      add_flash(_("At least 1 %{model} must be selected for Policy Simulation") %
        {:model => ui_lookup(:model => "Vm")}, :error)
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
    else
      session[:tag_items] = vms       # Set the array of tag items
      session[:tag_db] = VmOrTemplate # Remember the DB
      if @explorer
        @edit ||= {}
        @edit[:explorer] = true       # Since no @edit, create @edit and save explorer to use while building url for vms in policy sim grid
        session[:edit] = @edit
        policy_sim
        @refresh_partial = "layouts/policy_sim"
      else
        render :update do |page|
          page.redirect_to :controller => 'vm', :action => 'policy_sim'   # redirect to build the policy simulation screen
        end
      end
    end
  end
  alias_method :image_policy_sim, :polsimvms
  alias_method :instance_policy_sim, :polsimvms
  alias_method :vm_policy_sim, :polsimvms
  alias_method :miq_template_policy_sim, :polsimvms

  # End of common VM button handler routines

  # Common Cluster button handler routines
  def process_clusters(clusters, task)
    clusters, _clusters_out_region = filter_ids_in_region(clusters, _("Cluster"))
    return if clusters.empty?

    if task == "destroy"
      EmsCluster.where(:id => clusters).order("lower(name)").each do |cluster|
        id = cluster.id
        cluster_name = cluster.name
        audit = {:event => "ems_cluster_record_delete_initiated", :message => "[#{cluster_name}] Record delete initiated", :target_id => id, :target_class => "EmsCluster", :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      EmsCluster.destroy_queue(clusters)
    else
      EmsCluster.where(:id => clusters).order("lower(name)").each do |cluster|
        cluster_name = cluster.name
        begin
          cluster.send(task.to_sym) if cluster.respond_to?(task)    # Run the task
        rescue => err
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': %{error_message}") %
            {:model         => ui_lookup(:model => "EmsCluster"),
             :name          => cluster_name,
             :task          => task,
             :error_message => err.message}, :error) # Push msg and error flag
        else
          add_flash(_("%{model}: %{task} successfully initiated") % {:model => ui_lookup(:model => "EmsCluster"), :task => task})
        end
      end
    end
  end

  # Common RP button handler routines
  def process_resourcepools(rps, task)
    rps, _rps_out_region = filter_ids_in_region(rps, "Resource Pool")
    return if rps.empty?

    if task == "destroy"
      ResourcePool.where(:id => rps).order("lower(name)").each do |rp|
        id = rp.id
        rp_name = rp.name
        audit = {:event => "rp_record_delete_initiated", :message => "[#{rp_name}] Record delete initiated", :target_id => id, :target_class => "ResourcePool", :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      ResourcePool.destroy_queue(rps)
    else
      ResourcePool.where(:id => rps).order("lower(name)").each do |rp|
        rp_name = rp.name
        begin
          rp.send(task.to_sym) if rp.respond_to?(task)    # Run the task
        rescue => err
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': %{error_message}") %
            {:model         => ui_lookup(:model => "ResourcePool"),
             :name          => rp_name,
             :task          => task,
             :error_message => err.message}, :error)
        else
          add_flash(_("%{model} \"%{name}\": %{task} successfully initiated") % {:model => ui_lookup(:model => "ResourcePool"), :name => rp_name, :task => task})
        end
      end
    end
  end

  def cluster_button_operation(method, display_name)
    clusters = []

    # Either a list or coming from a different controller (eg from host screen, go to its clusters)
    if @lastaction == "show_list" || @layout != "ems_cluster"
      clusters = find_checked_items
      if clusters.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:tables => "ems_clusters"), :task => display_name}, :error)
      else
        process_clusters(clusters, method)
      end

      if @lastaction == "show_list" # In cluster controller, refresh show_list, else let the other controller handle it
        show_list
        @refresh_partial = "layouts/gtl"
      end

    else # showing 1 cluster
      if params[:id].nil? || EmsCluster.find_by_id(params[:id]).nil?
        add_flash(_("%{record} no longer exists") % {:record => ui_lookup(:tables => "ems_cluster")}, :error)
      else
        clusters.push(params[:id])
        process_clusters(clusters, method)  unless clusters.empty?
      end

      params[:display] = @display
      show

      # TODO: tells callers to go back to show_list because this Host may be gone
      # Should be refactored into calling show_list right here
      if method == 'destroy'
        @single_delete = true unless flash_errors?
      end
      if ["vms", "hosts"].include?(@display)
        @refresh_partial = "layouts/gtl"
      else
        @refresh_partial = "config"
      end
    end

    clusters.count
  end

  # Scan all selected or single displayed cluster(s)
  def scanclusters
    assert_privileges("ems_cluster_scan")
    cluster_button_operation('scan', _('Analysis'))
  end

  def each_host(host_ids, task_name)
    Host.where(:id => host_ids).order("lower(name)").each do |host|
      begin
        yield host
      rescue => err
        add_flash(_("%{model} \"%{name}\": Error during '%{task}': %{message}") %
                  {
                    :model   => ui_lookup(:model => "Host"),
                    :name    => host.name,
                    :task    => task_name,
                    :message => err.message
                  }, :error)
      end
    end
  end

  # Common Host button handler routines
  def process_hosts(hosts, task, display_name = nil)
    hosts, _hosts_out_region = filter_ids_in_region(hosts, _("Host"))
    return if hosts.empty?
    task_name = (display_name || task)

    case task
    when "refresh_ems"
      Host.refresh_ems(hosts)
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % \
        {:task        => (display_name || task_name(task)),
         :count_model => pluralize(hosts.length, "Host")})
      AuditEvent.success(:userid => session[:userid], :event => "host_#{task}",
          :message => "'#{task_name}' successfully initiated for #{pluralize(hosts.length, "Host")}",
          :target_class => "Host")
    when "destroy"
      each_host(hosts, task_name) do |host|
        audit = {:event => "host_record_delete_initiated", :message => "[#{host.name}] Record delete initiated", :target_id => id, :target_class => "Host", :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      Host.destroy_queue(hosts)
    when "scan"
      each_host(hosts, task_name) do |host|
        if host.respond_to?(:scan)
          host.send(task.to_sym, session[:userid]) # Scan needs userid
          add_flash(_("\"%{record}\": %{task} successfully initiated") % {:record => host.name, :task => (display_name || task)})
        else
          add_flash(_("\"%{task}\": not supported for %{hostname}") % {:hostname => host.name, :task => (task_name || task)}, :error)
        end
      end
    else
      each_host(hosts, task_name) do |host|
        if host.respond_to?(task) && host.is_available?(task)
          host.send(task.to_sym)
          add_flash(_("\"%{record}\": %{task} successfully initiated") % {:record => host.name, :task => (display_name || task)})
        else
          add_flash(_("\"%{task}\": not available for %{hostname}") % {:hostname => host.name, :task => (display_name || task)}, :error)
        end
      end
    end
  end

  # Common Stacks button handler routines
  def process_orchestration_stacks(stacks, task, _ = nil)
    stacks, = filter_ids_in_region(stacks, "OrchestrationStack")
    return if stacks.empty?

    if task == "destroy"
      OrchestrationStack.where(:id => stacks).order("lower(name)").each do |stack|
        id = stack.id
        stack_name = stack.name
        audit = {:event        => "stack_record_delete_initiated",
                 :message      => "[#{stack_name}] Record delete initiated",
                 :target_id    => id,
                 :target_class => "OrchestrationStack",
                 :userid       => session[:userid]}
        AuditEvent.success(audit)
      end
      OrchestrationStack.destroy_queue(stacks)
    end
  end

  # Refresh all selected or single displayed host(s)
  def refreshhosts
    assert_privileges("host_refresh")
    host_button_operation('refresh_ems', _('Refresh'))
  end

  # Scan all selected or single displayed host(s)
  def scanhosts
    assert_privileges("host_scan")
    host_button_operation('scan', _('Analysis'))
  end

  def check_compliance_hosts
    assert_privileges("host_check_compliance")
    host_button_operation('check_compliance_queue', _('Compliance Check'))
  end

  def analyze_check_compliance_hosts
    assert_privileges("host_analyze_check_compliance")
    host_button_operation('scan_and_check_compliance_queue', _('Analyze and Compliance Check'))
  end

  # Handle the Host power buttons
  POWER_BUTTON_NAMES = {
    "reboot"           => _("Restart"),
    "start"            => _("Power On"),
    "stop"             => _("Power Off"),
    "enter_maint_mode" => _("Enter Maintenance Mode"),
    "exit_maint_mode"  => _("Exit Maintenance Mode"),
    "standby"          => _("Shutdown to Standby Mode")
  }
  def powerbutton_hosts(method)
    assert_privileges(params[:pressed])
    host_button_operation(method, POWER_BUTTON_NAMES[method] || method.titleize)
  end

  def host_button_operation(method, display_name)
    hosts = []

    # Either a list or coming from a different controller (eg from ems screen, go to its hosts)
    if @lastaction == "show_list" || @layout != "host"
      hosts = find_checked_items
      if hosts.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:tables => "host"), :task => display_name}, :error)
      else
        process_hosts(hosts, method, display_name)
      end

      if @lastaction == "show_list" # In host controller, refresh show_list, else let the other controller handle it
        show_list
        @refresh_partial = "layouts/gtl"
      end

    else # showing 1 host
      if params[:id].nil? || Host.find_by_id(params[:id]).nil?
        add_flash(_("%{record} no longer exists") % {:record => ui_lookup(:table => "host")}, :error)
      else
        hosts.push(params[:id])
        process_hosts(hosts, method, display_name)  unless hosts.empty?
      end

      params[:display] = @display
      show

      # TODO: tells callers to go back to show_list because this Host may be gone
      # Should be refactored into calling show_list right here
      if method == 'destroy'
        @single_delete = true unless flash_errors?
      end
      if @display == "vms"
        @refresh_partial = "layouts/gtl"
      else
        @refresh_partial = "config"
      end
    end

    hosts.count
  end

  def process_storage(storages, task)
    storages, _storages_out_region = filter_ids_in_region(storages, _("Datastore"))
    return if storages.empty?

    if task == "destroy"
      Storage.where(:id => storages).order("lower(name)").each do |storage|
        id = storage.id
        storage_name = storage.name
        audit = {:event => "storage_record_delete_initiated", :message => "[#{storage_name}] Record delete initiated", :target_id => id, :target_class => "Storage", :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      Storage.destroy_queue(storages)
      add_flash(n_("Delete initiated for Datastore from the CFME Database",
                   "Delete initiated for Datastores from the CFME Database", storages.length))
    else
      Storage.where(:id => storages).order("lower(name)").each do |storage|
        storage_name = storage.name
        begin
          if task == "scan"
            storage.send(task.to_sym, session[:userid]) # Scan needs userid
          else
            storage.send(task.to_sym) if storage.respond_to?(task)    # Run the task
          end
        rescue => err
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': %{error_message}") %
            {:model         => ui_lookup(:model => "Storage"),
             :name          => storage_name,
             :task          => task,
             :error_message => err.message}, :error) # Push msg and error flag
        else
          if task == "refresh_ems"
            add_flash(_("\"%{record}\": Refresh successfully initiated") % {:record => storage_name})
          else
            add_flash(_("\"%{record}\": %{task} successfully initiated") % {:record => storage_name, :task => task})
          end
        end
      end
    end
  end

  def storage_button_operation(method, display_name)
    storages = []

    # Either a list or coming from a different controller (eg from host screen, go to its storages)
    if @lastaction == "show_list" || @layout != "storage"
      storages = find_checked_items

      if method == 'scan' && !Storage.batch_operation_supported?('smartstate_analysis', storages)
        render_flash_not_applicable_to_model(_('Smartstate Analysis'), ui_lookup(:tables => "storage"))
        return
      end
      if storages.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:tables => "storage"), :task => display_name}, :error)
      else
        process_storage(storages, method)
      end

      if @lastaction == "show_list" # In storage controller, refresh show_list, else let the other controller handle it
        show_list
        @refresh_partial = "layouts/gtl"
      end

    else # showing 1 storage
      if params[:id].nil? || Storage.find_by_id(params[:id]).nil?
        add_flash(_("%{record} no longer exists") % {:record => ui_lookup(:tables => "storage")}, :error)
      else
        storages.push(params[:id])
        process_storage(storages, method)  unless storages.empty?
      end

      params[:display] = @display
      show
      if ["vms", "hosts"].include?(@display)
        @refresh_partial = "layouts/gtl"
      else
        @refresh_partial = "config"
      end
    end

    storages.count
  end

  # Refresh all selected or single displayed Datastore(s)
  def refreshstorage
    assert_privileges("storage_refresh")
    storage_button_operation('refresh_ems', _('Refresh'))
  end

  # Scan all selected or single displayed storage(s)
  def scanstorage
    assert_privileges("storage_scan")
    storage_button_operation('scan', _('Analysis'))
  end

  # Delete all selected or single displayed host(s)
  def deletehosts
    assert_privileges("host_delete")
    delete_elements(Host, :process_hosts)
  end

  # Delete all selected or single displayed stack(s)
  def orchestration_stack_delete
    assert_privileges("orchestration_stack_delete")
    delete_elements(OrchestrationStack, :process_orchestration_stacks)
  end

  # Delete all selected or single displayed datastore(s)
  def deletestorages
    assert_privileges("storage_delete")
    datastores = []
    if @lastaction == "show_list" || (@lastaction == "show" && @layout != "storage")  # showing a list, scan all selected hosts
      datastores = find_checked_items
      if datastores.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:tables => "storage"), :task => display_name}, :error)
      end
      ds_to_delete = []
      datastores.each do |s|
        ds = Storage.find_by_id(s)
        if ds.vms_and_templates.length <= 0 && ds.hosts.length <= 0
          ds_to_delete.push(s)
        else
          add_flash(_("\"%{datastore_name}\": cannot be removed, has vms or hosts") %
            {:datastore_name => ds.name}, :warning)
        end
      end
      process_storage(ds_to_delete, "destroy")  unless ds_to_delete.empty?
    else # showing 1 datastore, delete it
      if params[:id].nil? || Storage.find_by_id(params[:id]).nil?
        add_flash(_("%{record} no longer exists") % {:record => ui_lookup(:tables => "storage")}, :error)
      else
        datastores.push(params[:id])
      end
      process_storage(datastores, "destroy")  unless datastores.empty?
      @single_delete = true unless flash_errors?
      add_flash(_("The selected %{record} was deleted") %
        {:record => ui_lookup(:table => "storages")}) if @flash_array.nil?
    end
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    end
  end

  def delete_elements(model_class, destroy_method)
    elements = []
    if @lastaction == "show_list" || (@lastaction == "show" && @layout != model_class.table_name.singularize)  # showing a list
      elements = find_checked_items
      if elements.empty?
        add_flash(_("No %{model} were selected for deletion") %
          {:model => ui_lookup(:tables => model_class.table_name)}, :error)
      end
      send(destroy_method, elements, "destroy") unless elements.empty?
      add_flash(_("Delete initiated for %{count_model} from the CFME Database") %
        {:count_model => pluralize(elements.length, ui_lookup(:table => model_class.table_name))}) unless flash_errors?
    else # showing 1 element, delete it
      if params[:id].nil? || model_class.find_by_id(params[:id]).nil?
        add_flash(_("%{record} no longer exists") % {:record => ui_lookup(:table => model_class.table_name)}, :error)
      else
        elements.push(params[:id])
      end
      send(destroy_method, elements, "destroy") unless elements.empty?
      @single_delete = true unless flash_errors?
      add_flash(_("The selected %{record} was deleted") %
        {:record => ui_lookup(:table => model_class.table_name)}) if @flash_array.nil?
    end
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    end
  end

  # Delete all selected or single displayed cluster(s)
  def deleteclusters
    assert_privileges("ems_cluster_delete")
    delete_elements(EmsCluster, :process_clusters)
  end

  # Delete all selected or single displayed RP(s)
  def deleteresourcepools
    assert_privileges("resource_pool_delete")
    delete_elements(ResourcePool, :process_resourcepools)
  end

  def pfx_for_vm_button_pressed(_button_pressed)
    if params[:pressed].starts_with?("image_")
      return "image"
    elsif params[:pressed].starts_with?("instance_")
      return "instance"
    elsif params[:pressed].starts_with?("miq_template_")
      return "miq_template"
    else
      return "vm"
    end
  end

  def process_vm_buttons(pfx)
    case params[:pressed]
    when "#{pfx}_policy_sim"                then polsimvms
    when "#{pfx}_compare"                   then comparemiq
    when "#{pfx}_scan"                      then scanvms
    when "#{pfx}_collect_running_processes" then getprocessesvms
    when "#{pfx}_sync"                      then syncvms
    when "#{pfx}_tag"                       then tag(VmOrTemplate)
    when "#{pfx}_delete"                    then deletevms
    when "#{pfx}_protect"                   then assign_policies(VmOrTemplate)
    when "#{pfx}_edit"                      then edit_record
    when "#{pfx}_refresh"                   then refreshvms
    when "#{pfx}_start"                     then startvms
    when "#{pfx}_stop"                      then stopvms
    when "#{pfx}_suspend"                   then suspendvms
    when "#{pfx}_pause"                     then pausevms
    when "#{pfx}_shelve"                    then shelvevms
    when "#{pfx}_shelveoffloadvms"          then shelveoffloadvms
    when "#{pfx}_reset"                     then resetvms
    when "#{pfx}_check_compliance"          then check_compliance_vms
    when "#{pfx}_reconfigure"               then reconfigurevms
    when "#{pfx}_retire"                    then retirevms
    when "#{pfx}_retire_now"                then retirevms_now
    when "#{pfx}_right_size"                then vm_right_size
    when "#{pfx}_ownership"                 then set_ownership
    when "#{pfx}_guest_shutdown"            then guestshutdown
    when "#{pfx}_guest_standby"             then gueststandby
    when "#{pfx}_guest_restart"             then guestreboot
    when "#{pfx}_miq_request_new"           then prov_redirect
    when "#{pfx}_clone"                     then prov_redirect("clone")
    when "#{pfx}_migrate"                   then prov_redirect("migrate")
    when "#{pfx}_publish"                   then prov_redirect("publish")
    when "#{pfx}_terminate"                 then terminatevms
    end
  end

  def owner_changed?(owner)
    return false if @edit[:new][owner].blank?
    @edit[:new][owner] != @edit[:current][owner]
  end

  def show_association(action, display_name, listicon, method, klass, association = nil, conditions = nil)
    # Ajax request means in explorer, or if current explorer is one of the explorer controllers
    @explorer = true if request.xml_http_request? && explorer_controller?
    if @explorer  # Save vars for tree history array
      @x_show = params[:x_show]
      @sb[:action] = @lastaction = action
    end
    @record = identify_record(params[:id], controller_to_model)
    @view = session[:view]                  # Restore the view from the session to get column names for the display
    return if record_no_longer_exists?(@record, klass.to_s)
    @lastaction = action
    if params[:show] || params[:x_show]
      id = params[:show] ? params[:show] : params[:x_show]
      if method.kind_of?(Array)
        obj = @record
        while meth = method.shift
          obj = obj.send(meth)
        end
        @item = obj.find(from_cid(id))
      else
        @item = @record.send(method).find(from_cid(id))
      end

      drop_breadcrumb(:name => "#{@record.name} (#{display_name})",
                      :url  => "/#{controller_name}/#{action}/#{@record.id}?page=#{@current_page}")
      drop_breadcrumb(:name => @item.name,
                      :url  => "/#{controller_name}/#{action}/#{@record.id}?show=#{@item.id}")
      @view = get_db_view(klass, :association => association)
      show_item
    else
      drop_breadcrumb({:name => @record.name,
                       :url  => "/#{controller_name}/show/#{@record.id}"}, true)
      drop_breadcrumb(:name => "#{@record.name} (#{display_name})",
                      :url  => "/#{controller_name}/#{action}/#{@record.id}")
      @listicon = listicon
      if association.nil?
        show_details(klass, :conditions => conditions)
      else
        show_details(klass, :association => association, :conditions => conditions)
      end
    end
  end
end
