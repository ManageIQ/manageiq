module ApplicationController::CiProcessing
  extend ActiveSupport::Concern

  included do
    self.hide_action(:process_elements)
  end

  # Set Ownership selected db records
  def set_ownership(klass = "VmOrTemplate")
    assert_privileges(params[:pressed])
    @edit = Hash.new
    @edit[:key] = "ownership_edit__new"
    @edit[:current] = Hash.new
    @edit[:new] = Hash.new
    @edit[:klass] = klass.constantize
    # check to see if coming from show_list or drilled into vms from another CI
    if request.parameters[:controller] == "vm" || ["all_vms","vms", "instances", "images"].include?(params[:display])
      rec_cls = "vm"
    elsif ["miq_templates","images"].include?(params[:display]) || params[:pressed].starts_with?("miq_template_")
      rec_cls = "miq_template"
    else
      rec_cls = request.parameters[:controller]
    end
    recs = Array.new
    if !session[:checked_items].nil? && @lastaction == "set_checked_items"
      recs = session[:checked_items]
    else
      recs = find_checked_items
    end
    if recs.blank?
      recs = [params[:id].to_i]
    end
    if recs.length < 1
      add_flash(_("One or more %{model} must be selected to %{task}") % {:model=>Dictionary::gettext(db.to_s, :type=>:model, :notfound=>:titleize).pluralize, :task=>"Set Ownership"}, :error)
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
      return
    else
      @edit[:ownership_items] = Array.new # Set the array of set ownership items
      recs.each do |r|
        @edit[:ownership_items].push(r.to_i)
      end
    end

    if @explorer
      @edit[:explorer] = true
      ownership
    else
      render :update do |page|
        if role_allows(:feature=>"vm_ownership")
          page.redirect_to :controller=>"#{rec_cls}", :action => 'ownership'              # redirect to build the ownership screen
        end
      end
    end
  end
  alias image_ownership set_ownership
  alias instance_ownership set_ownership
  alias vm_ownership set_ownership
  alias miq_template_ownership set_ownership
  alias service_ownership set_ownership

  # Assign/unassign ownership to a set of objects
  def ownership
    @edit = session[:edit] if !@explorer  #only do this for non-explorer screen
    ownership_build_screen
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
    drop_breadcrumb( {:name=>"Set Ownership", :url=>"/vm_common/ownership"} )
    @in_a_form = @ownershipedit = true
    build_targets_hash(@ownershipitems)
    if @edit[:explorer]
      @refresh_partial = "shared/views/ownership"
    else
      render :action=>"show"
    end
  end

  DONT_CHANGE_OWNER = "0"

  # Build the ownership assignment screen
  def ownership_build_screen
    @users = Hash.new   # Users array for first chooser
    User.all.each{|u| @users[u.name] = u.id.to_s}
    record = @edit[:klass].find(@edit[:ownership_items][0])
    user = record.evm_owner if @edit[:ownership_items].length == 1
    @edit[:new][:user] = user ? user.id.to_s : nil            # Set to first category, if not already set

    @groups = Hash.new                    # Create new entries hash (2nd pulldown)
    # need to do this only if 1 vm is selected and miq_group has been set for it
    group = record.miq_group if @edit[:ownership_items].length == 1
    @edit[:new][:group] = group ? group.id.to_s : nil
    MiqGroup.all.each{|g| @groups[g.description] = g.id.to_s}

    @edit[:new][:user] = @edit[:new][:group] = DONT_CHANGE_OWNER if @edit[:ownership_items].length > 1

    @ownershipitems = @edit[:klass].find(@edit[:ownership_items]).sort_by(&:name) # Get the db records that are being tagged
    @view = get_db_view(@edit[:klass] == VmOrTemplate ? Vm : @edit[:klass])       # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@ownershipitems, :only=>@view.cols + ['id'])
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
        add_flash(_("%s was cancelled by the user") % "Set Ownership")
        if @edit[:explorer]
          @edit = @sb[:action] = nil
          replace_right_cell
        else
          session[:flash_msgs] = @flash_array
          render :update do |page|
            page.redirect_to(@breadcrumbs[-2][:url])               # Go to previous page using breadcrumbs
          end
        end
      when "save"
        opts = Hash.new
        unless @edit[:new][:user] == DONT_CHANGE_OWNER
          if owner_changed?(:user)
            opts[:owner] = User.find(@edit[:new][:user])
          elsif @edit[:new][:user].blank?     #to clear previously set user
            opts[:owner] = nil
          end
        end

        unless @edit[:new][:group] == DONT_CHANGE_OWNER
          if owner_changed?(:group)
            opts[:group] = MiqGroup.find_by_id(@edit[:new][:group])
          elsif @edit[:new][:group].blank?    #to clear previously set group
            opts[:group] = nil
          end
        end

        result = @edit[:klass].set_ownership(@edit[:ownership_items],opts)
        unless result == true
          result["missing_ids"].each {|msg| add_flash(msg, :error)} if result["missing_ids"]
          result["error_updating"].each {|msg| add_flash(msg, :error)} if result["error_updating"]
          render :update do |page|
            page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
          end
        else
          object_types = object_types_for_flash_message(@edit[:klass], @edit[:ownership_items])

          flash = _("Ownership saved for selected %s") %  object_types
          add_flash(flash)
          if @edit[:explorer]
            @edit = @sb[:action] = nil
            replace_right_cell
          else
            session[:flash_msgs] = @flash_array
            render :update do |page|
              page.redirect_to(@breadcrumbs[-2][:url])               # Go to previous page using breadcrumbs
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
      add_flash(_("%{task} does not apply to selected %{model}") % {:model=>ui_lookup(:table => "miq_template"), :task=>"Set Retirement Dates"}, :error)
      render_flash { |page| page << '$(\'#main_div\').scrollTop();' }
      return
    end
    # check to see if coming from show_list or drilled into vms from another CI
    if request.parameters[:controller] == "vm" || %w(all_vms instances vms).include?(params[:display])
      rec_cls = "vm"
    elsif request.parameters[:controller] == "service"
      rec_cls =  "service"
    end
    if vms.blank?
      session[:retire_items] = [params[:id]]
    else
      if vms.length < 1
        add_flash(_("At least %{num} %{model} must be selected for %{action}") % {:num=>"one", :model=>ui_lookup(:model=>"Vm"), :task=>"tagging"}, :error)
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
      render :update do |page|
        page.redirect_to :controller => rec_cls, :action => 'retire'      # redirect to build the retire screen
      end
    end
  end
  alias image_retire retirevms
  alias instance_retire retirevms
  alias vm_retire retirevms
  alias service_retire retirevms

  # Build the retire VMs screen
  def retire
    @sb[:explorer] = true if @explorer
    kls = request.parameters[:controller] == "service" ? Service : Vm
    if params[:button]
      if params[:button] == "cancel"
        flash = "Set/remove retirement date was cancelled by the user"
        @sb[:action] = nil
      elsif params[:button] == "save"
        d = session[:retire_items].length == 1 ? "date" : "dates"
        if session[:retire_date].blank?
          t = nil
          session[:retire_warn] = nil
          flash = _("Retirement %s removed") % d
        else
          t = "#{session[:retire_date]} 00:00:00 Z"
          flash = _("Retirement %{date_text} set to %{rdate}") % {:date_text=>d, :rdate=>session[:retire_date]}
        end
        kls.retire(session[:retire_items], :date=>t, :warn=>session[:retire_warn].to_i)       # Call the model to retire the VM(s)
        @sb[:action] = nil
      end
      add_flash(flash)
      if @sb[:explorer]
        replace_right_cell
      else
        session[:flash_msgs] = @flash_array.dup
        redirect_to @breadcrumbs[-2][:url]
      end
      return
    end
    @gtl_url = "/vm/retire?"
    session[:changed] = @changed = false
    drop_breadcrumb( {:name=>"Retire #{kls.to_s.pluralize}", :url=>"/#{session[:controller]}/tagging"} )
    session[:cat] = nil                 # Clear current category
    @retireitems = kls.find(session[:retire_items]).sort_by(&:name) # Get the db records
    build_targets_hash(@retireitems)
    @view = get_db_view(kls)              # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@retireitems, :only=>@view.cols + ['id'])
    if @retireitems.length == 1 && @retireitems[0].retires_on != nil
      t = @retireitems[0].retires_on      # Single VM, set to current time
      #w = @retireitems[0].retirement[:warn]  if @retireitems[0].retirement   # Single VM, get retirement warn
      w = @retireitems[0].retirement_warn if @retireitems[0].retirement_warn    # Single VM, get retirement warn
    else
      t = nil
    end
    session[:retire_date] = t == nil ? nil : "#{t.month}/#{t.day}/#{t.year}"
    session[:retire_warn] = w
    @in_a_form = true
    @refresh_partial = "shared/views/retire" if @explorer
  end

  # Ajax method fired when retire date is changed
  def retire_date_changed
    changed = (params[:miq_date_1] != session[:retire_date])

    if params[:miq_date_1]
      session[:retire_date] = params[:miq_date_1] if params[:miq_date_1]
    end
    session[:retire_warn] = params[:retirement_warn] if params[:retirement_warn]
    if !params[:miq_date_1] && !params[:retirement_warn]
      session[:retire_date] = nil
      session[:retire_warn] = nil
    end
    render :update do |page|
      if session[:retire_date].blank?
        session[:retire_warn] = ""
        page << javascript_hide("remove_button")
        page << javascript_disable_field('retirement_warn')
        page << "$('#retirement_warn').val('');"
      else
        page << javascript_show("remove_button")
        page << javascript_enable_field('retirement_warn')
      end
      page << javascript_for_miq_button_visibility_changed(changed)
      page << "miqSparkle(false);"
    end
  end

  def vm_right_size
    assert_privileges(params[:pressed])
    # check to see if coming from show_list or drilled into vms from another CI
    rec_cls = "vm"
    recs = params[:display] ? find_checked_items : [params[:id].to_i]
    if recs.length < 1
      add_flash(_("One or more %{model} must be selected to %{task}") % {:model => ui_lookup(:table => request.parameters[:controller]), :task=>"Right-Size Recommendations"}, :error)
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
      return
    else
      if VmOrTemplate.includes_template?(recs)
        add_flash(_("%{task} does not apply to selected %{model}") % {:model=>ui_lookup(:table => "miq_template"), :task=>"Right-Size Recommendations"}, :error)
        render_flash { |page| page << '$(\'#main_div\').scrollTop();' }
        return
      end
    end
    if @explorer
      @refresh_partial = "vm_common/right_size"
      right_size
      replace_right_cell if @orig_action == "x_history"
    else
      render :update do |page|
        if role_allows(:feature=>"vm_right_size")
          page.redirect_to :controller=>"#{rec_cls}", :action => 'right_size', :id=>recs[0], :escape=>false           # redirect to build the ownership screen
        end
      end
    end
  end
  alias instance_right_size vm_right_size


  # Assign/unassign ownership to a set of objects
  def reconfigure
    @edit = session[:edit] if !@explorer
    @in_a_form = @reconfigure = true
    reconfigure_build_screen
    @edit[:current] = copy_hash(@edit[:new])
    session[:edit] = @edit
    drop_breadcrumb( {:name=>"Reconfigure", :url=>"/vm_common/reconfigure"} )
    build_targets_hash(@reconfigureitems)
    if !@explorer
      render :action=>"show"
    end
  end

  def reconfigure_field_changed
    return unless load_edit("reconfigure__new")
    reconfigure_get_form_vars
    render :update do |page|                    # Use JS to update the display
      if @edit[:new][:cb_memory]
        page << javascript_show("memory_div")
      else
        page << javascript_hide("memory_div")
      end
      if @edit[:new][:cb_cpu]
        page << javascript_show("cpu_div")
      else
        page << javascript_hide("cpu_div")
      end
    end
  end

  def reconfigure_update
    return unless load_edit("reconfigure__new")
    reconfigure_get_form_vars
    url = @breadcrumbs[1][:url].split('/')
    case params[:button]
    when "cancel"
      flash = _("VM Reconfigure Request was cancelled by the user")
      if @edit[:explorer]
        add_flash(flash)
        @sb[:action] = nil
        replace_right_cell
      else
        render :update do |page|
          if url[2] == "show"
            page.redirect_to :controller=>url[1], :action =>url[2], :id=>url[3], :flash_msg=>flash
          else
            page.redirect_to :action=>@lastaction, :flash_msg=>flash
          end
        end
      end
    when "submit"
      if !@edit[:new][:cb_cpu] && !@edit[:new][:cb_memory]
        add_flash(_("At least one option must be selected to reconfigure"), :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end

      #check to make sure memory is numeric
      if @edit[:new][:cb_memory]
        if @edit[:new][:old_memory].to_s == @edit[:new][:memory].to_s &&
            @edit[:new][:old_mem_typ] == @edit[:new][:mem_typ]
          add_flash(_("Change %s value to submit reconfigure request") % "Memory", :error)
        elsif (@edit[:new][:memory] =~ /^[-+]?[0-9]*[0-9]+$/).nil?
          add_flash(_("%s must be an integer") % "Memory", :error)
        end
      end

      if @edit[:new][:cb_cpu] && @edit[:new][:old_cpu_count].to_s == @edit[:new][:cpu_count].to_s
        add_flash(_("Change %s value to submit reconfigure request") % "Processors", :error)
      end

      if @flash_array
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end

      options = {
        :src_ids=>@edit[:reconfigure_items]
      }
      # Convert memory to MB before passing on to model, don't multiply by 1024, if value is not numeric
      options[:vm_memory] = @edit[:new][:mem_typ] == "MB" ? @edit[:new][:memory] : (@edit[:new][:memory].to_i.zero? ? @edit[:new][:memory] : @edit[:new][:memory].to_i * 1024) if @edit[:new][:cb_memory]
      options[:number_of_cpus] = @edit[:new][:cpu_count] if @edit[:new][:cb_cpu]
      valid = VmReconfigureRequest.validate_request(options) if @edit[:new][:cb_memory]
      if valid
        valid.each do |v|
          add_flash(v, :error)
        end
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end

      if @edit[:req_id] ? VmReconfigureRequest.update_request(@edit[:req_id],options, session[:userid]) : VmReconfigureRequest.create_request(options, session[:userid])
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
        @edit[:errors].each { |msg| add_flash(msg, :error) }
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    end
  end

  # edit single selected Object
  def edit_record
    assert_privileges(params[:pressed])
    obj = find_checked_items
    db = params[:db] if params[:db]

    case params[:pressed]
      when "miq_template_edit"
        @redirect_controller = "miq_template"
      when "image_edit","instance_edit","vm_edit"
        @redirect_controller = "vm"
      when "host_edit"
        @redirect_controller = "host"
        session[:host_items] = obj if obj.length > 1
    end
    @redirect_id = obj[0] if obj.length == 1      # not redirecting to an id if multi host are selected for credential edit

    if !["ScanItemSet","Condition","Schedule","MiqAeInstance"].include?(db)
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
        if cond.filename == nil
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
  def show_details(db, options={})  # Pass in the db, parent vm is in @vm
    association = options[:association]
    conditions  = options[:conditions]
    # generate the grid/tile/list url to come back here when gtl buttons are pressed
    @gtl_url       = "/#{@db}/#{@listicon.pluralize}/#{@record.id.to_s}?"
    @showtype      = "details"
    @no_checkboxes = true
    @showlinks     = true

    @view, @pages = get_view(db,
                            :parent=>@record,
                            :association=>association,
                            :conditions => conditions,
                            :dbname=>"#{@db}item")  # Get the records into a view & paginator

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
    session[:db] = @db if !@db.nil?
    @db = session[:db] if !session[:db].nil?

    @record = identify_record(params[:id])
    return if record_no_longer_exists?(@record)

    @view = session[:view]                  # Restore the view from the session to get column names for the display
    @display = "snia_local_file_systems"
    if params[:show] != nil
      @item = SniaLocalFileSystem.find_by_id(from_cid(params[:show]))
      drop_breadcrumb( {:name=>@record.evm_display_name + " (" + ui_lookup(:tables=>"snia_local_file_system") + ")", :url=>"/#{@db}/snia_local_file_systems/#{@record.id}?page=#{@current_page}"} )
      drop_breadcrumb( {:name=>@item.evm_display_name, :url=>"/#{@db}/show/#{@record.id}?show=#{@item.id}"} )
      show_item
    else
      drop_breadcrumb( {:name=>@record.evm_display_name + " (" + ui_lookup(:tables=>"snia_local_file_system") + ")", :url=>"/#{@db}/snia_local_file_systems/#{@record.id}"} )
      # generate the grid/tile/list url to come back here when gtl buttons are pressed
      @gtl_url = "/#{@db}/snia_local_file_systems/" + @record.id.to_s + "?"
      @showtype = "details"

      table_name = "snia_local_file_systems"
      model_name = table_name.classify.constantize
      drop_breadcrumb( {:name=>@record.evm_display_name+" (All #{ui_lookup(:tables => @display.singularize)})", :url=>"/#{self.class.table_name}/show/#{@record.id}?display=#{@display}"} )
      @view, @pages = get_view(model_name, :parent=>@record, :parent_method =>:local_file_systems)  # Get the records (into a view) and the paginator
      render :action => 'show'
    end
  end

  def cim_base_storage_extents
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db if !@db.nil?
    @db = session[:db] if !session[:db].nil?

    @record = identify_record(params[:id])
    return if record_no_longer_exists?(@record)

    @view = session[:view]                  # Restore the view from the session to get column names for the display
    @display = "cim_base_storage_extents"
    if params[:show] != nil
      @item = CimBaseStorageExtent.find_by_id(from_cid(params[:show]))
      drop_breadcrumb( {:name=>@record.evm_display_name + " (" + ui_lookup(:tables=>"cim_base_storage_extent") + ")", :url=>"/#{@db}/cim_base_storage_extents/#{@record.id}?page=#{@current_page}"} )
      drop_breadcrumb( {:name=>@item.evm_display_name, :url=>"/#{@db}/show/#{@record.id}?show=#{@item.id}"} )
      show_item
    else
      drop_breadcrumb( {:name=>@record.evm_display_name + " (" + ui_lookup(:tables=>"cim_base_storage_extent") + ")", :url=>"/#{@db}/cim_base_storage_extents/#{@record.id}"} )
      # generate the grid/tile/list url to come back here when gtl buttons are pressed
      @gtl_url = "/#{@db}/cim_base_storage_extents/" + @record.id.to_s + "?"
      @showtype = "details"

      table_name = "cim_base_storage_extents"
      model_name = table_name.classify.constantize
      drop_breadcrumb( {:name=>@record.evm_display_name+" (All #{ui_lookup(:tables => @display.singularize)})", :url=>"/#{self.class.table_name}/show/#{@record.id}?display=#{@display}"} )
      @view, @pages = get_view(model_name, :parent=>@record, :parent_method =>:base_storage_extents)  # Get the records (into a view) and the paginator
      render :action => 'show'
    end
  end

  def get_record(db)
    if db == "host"
      @host = @record = identify_record(params[:id], Host)
    elsif db == "miq_template"
      @miq_template = @record = identify_record(params[:id], MiqTemplate)
    elsif ["vm_infra","vm_cloud","vm","vm_or_template"].include?(db)
      @vm = @record = identify_record(params[:id], VmOrTemplate)
    end
  end

  def guest_applications
    @explorer = true if request.xml_http_request? # Ajax request means in explorer
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db if !@db.nil?
    @db = session[:db] if !session[:db].nil?
    get_record(@db)
    @sb[:action] = params[:action]
    return if record_no_longer_exists?(@record)

    @lastaction = "guest_applications"
    if params[:show] != nil || params[:x_show] != nil
      id = params[:show] ? params[:show] : params[:x_show]
      @item = @record.guest_applications.find(from_cid(id))
      if Regexp.new(/linux/).match(@record.os_image_name.downcase)
        drop_breadcrumb( {:name=>@record.name+" (Packages)", :url=>"/#{@db}/guest_applications/#{@record.id}?page=#{@current_page}"} )
      else
        drop_breadcrumb( {:name=>@record.name+" (Applications)", :url=>"/#{@db}/guest_applications/#{@record.id}?page=#{@current_page}"} )
      end
      drop_breadcrumb( {:name=>@item.name, :url=>"/#{@db}/show/#{@record.id}?show=#{@item.id}"} )
      @view = get_db_view(GuestApplication)         # Instantiate the MIQ Report view object
      show_item
    else
      drop_breadcrumb( {:name=>@record.name, :url=>"/#{@db}/show/#{@record.id}"}, true )
      if Regexp.new(/linux/).match(@record.os_image_name.downcase)
        drop_breadcrumb( {:name=>@record.name+" (Packages)", :url=>"/#{@db}/guest_applications/#{@record.id}"} )
      else
        drop_breadcrumb( {:name=>@record.name+" (Applications)", :url=>"/#{@db}/guest_applications/#{@record.id}"} )
      end
      @listicon = "guest_application"
      show_details(GuestApplication)
    end
  end

  def patches
    @explorer = true if request.xml_http_request? # Ajax request means in explorer
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db if !@db.nil?
    @db = session[:db] if !session[:db].nil?
    get_record(@db)
    @sb[:action] = params[:action]
    return if record_no_longer_exists?(@record)

    @lastaction = "patches"
    if params[:show] != nil || params[:x_show] != nil
      id = params[:show] ? params[:show] : params[:x_show]
      @item = @record.patches.find(from_cid(id))
      drop_breadcrumb( {:name=>@record.name+" (Patches)", :url=>"/#{@db}/patches/#{@record.id}?page=#{@current_page}"} )
      drop_breadcrumb( {:name=>@item.name, :url=>"/#{@db}/patches/#{@record.id}?show=#{@item.id}"} )
      @view = get_db_view(Patch)
      show_item
    else
      drop_breadcrumb( {:name=>@record.name+" (Patches)", :url=>"/#{@db}/patches/#{@record.id}"} )
      @listicon = "patch"
      show_details(Patch)
    end
  end

  def groups
    @explorer = true if request.xml_http_request? # Ajax request means in explorer
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db if !@db.nil?
    @db = session[:db] if !session[:db].nil?
    get_record(@db)
    @sb[:action] = params[:action]
    return if record_no_longer_exists?(@record)

    @lastaction = "groups"
    if params[:show] != nil || params[:x_show] != nil
      id = params[:show] ? params[:show] : params[:x_show]
      @item = @record.groups.find(from_cid(id))
      drop_breadcrumb( {:name=>@record.name+" (Groups)", :url=>"/#{@db}/groups/#{@record.id}?page=#{@current_page}"} )
      drop_breadcrumb( {:name=>@item.name, :url=>"/#{@db}/groups/#{@record.id}?show=#{@item.id}"} )
      @user_names = @item.users
      @view = get_db_view(Account, :association=>"groups")
      show_item
    else
      drop_breadcrumb( {:name=>@record.name+" (Groups)", :url=>"/#{@db}/groups/#{@record.id}"} )
      @listicon = "group"
      show_details(Account, :association=>"groups")
    end
  end

  def users
    @explorer = true if request.xml_http_request? # Ajax request means in explorer
    @db = params[:db] ? params[:db] : request.parameters[:controller]
    session[:db] = @db if !@db.nil?
    @db = session[:db] if !session[:db].nil?
    get_record(@db)
    @sb[:action] = params[:action]
    return if record_no_longer_exists?(@record)

    @lastaction = "users"
    if params[:show] != nil || params[:x_show] != nil
      id = params[:show] ? params[:show] : params[:x_show]
      @item = @record.users.find(from_cid(id))
      drop_breadcrumb( {:name=>@record.name+" (Users)", :url=>"/#{@db}/users/#{@record.id}?page=#{@current_page}"} )
      drop_breadcrumb( {:name=>@item.name, :url=>"/#{@db}/show/#{@record.id}?show=#{@item.id}"} )
      @group_names = @item.groups
      @view = get_db_view(Account, :association=>"users")
      show_item
    else
      drop_breadcrumb( {:name=>@record.name+" (Users)", :url=>"/#{@db}/users/#{@record.id}"} )
      @listicon = "user"
      show_details(Account, :association=>"users")
    end
  end

# Discover hosts
  def discover
    assert_privileges("#{controller_name}_discover")
    session[:type] = params[:discover_type] if params[:discover_type]
    title = set_discover_title(session[:type],request.parameters[:controller])
    if params["cancel"]
      redirect_to :action => 'show_list', :flash_msg=>_("%s was cancelled by the user") % "#{title} Discovery"
    end
    @userid = ""
    @password = ""
    @verify = ""
    if session[:type] == "hosts"
      @discover_type = Host.host_discovery_types
    else
      @discover_type = ExtManagementSystem.ems_discovery_types
    end
    discover_type = Array.new
    @discover_type_checked = Array.new        # to keep track of checked items when start button is pressed
    if params["start"]
      audit = {:event=>"ms_and_host_discovery", :target_class=>"Host", :userid => session[:userid]}
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
          i +=1
        end

        @from = Hash.new
        @from[:first] = params[:from_first]
        @from[:second] = params[:from_second]
        @from[:third] = params[:from_third]
        @from[:fourth] = params[:from_fourth]
        @to = Hash.new
        @to[:first] = params[:from_first]
        @to[:second] = params[:from_second]
        @to[:third] = params[:from_third]
        @to[:fourth] = params[:to_fourth]
      end
      @in_a_form = true
      drop_breadcrumb( {:name=>"#{title} Discovery", :url=>"/host/discover"} )

      if request.parameters[:controller] == "ems_cloud" || params[:discover_type_ipmi].to_s == "1"
        @userid = params[:userid] if  params[:userid]
        @password = params[:password] if params[:password]
        @verify = params[:verify] if params[:verify]
        if request.parameters[:controller] == "ems_cloud" && params[:userid] == ""
          add_flash(_("%s is required") %  "Username", :error)
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
        add_flash(_("At least %{num} %{model} must be selected for %{action}") % {:num=>"1", :model=>"item", :action=>"discovery"}, :error)
        render :action => 'discover'
      else
        begin
          if request.parameters[:controller] != "ems_cloud"
            if params[:discover_type_ipmi].to_s == "1"
              options = {:discover_types=>discover_type, :credentials=>{:ipmi=>{:userid=>@userid,:password=>@password}} }
            else
              options = {:discover_types=>discover_type}
            end
            Host.discoverByIpRange(from_ip, to_ip, options)
          else
            EmsAmazon.discover_queue(@userid, @password)
          end
        rescue StandardError=>bang
  #       @flash_msg = "'Host Discovery' returned: " + bang.message; @flash_error = true
          add_flash(_("%s Discovery returned: ") % title << bang.message, :error)
          render :action => 'discover'
          return
        else
          AuditEvent.success(audit.merge(:message=>"#{title} discovery initiated (from_ip:[#{from_ip}], to_ip:[#{to_ip}])"))
          redirect_to :action => 'show_list', :flash_msg=>_("%{model}: %{task} successfully initiated") % {:model=>title, :task=>"Discovery"}
        end
      end
    end
    # Fell through, must be first time
    @in_a_form = true
    @title = "#{title} Discovery"
    @from = {:first=>"", :second=>"", :third=>"", :fourth=>""}
    @to = {:first=>"", :second=>"", :third=>"", :fourth=>""}
  end

  def set_discover_title(type, controller)
    if type == "hosts"
      return ui_lookup(:host_types => "hosts")
    else
      controller_table = ui_lookup(:tables => controller)
      if controller == "ems_cloud"
        return "Amazon #{controller_table}"
      else
        return controller_table
      end
    end
  end

  # AJAX driven routine to check for changes in ANY field on the discover form
  def discover_field_changed
    render :update do |page|                    # Use JS to update the display
      if params[:from_first]
        #params[:from][:first] =~ /[a-zA-Z]/
        if params[:from_first] =~ /[\D]/
          temp = params[:from_first].gsub(/[\.]/,"")
          field_shift = true if params[:from_first] =~ /[\.]/ && params[:from_first].gsub(/[\.]/,"") =~ /[0-9]/ && temp.gsub!(/[\D]/,"").nil?
          page << "$('#from_first').val('#{j_str(params[:from_first]).gsub(/[\D]/, "")}');"
          page << javascript_focus('from_second') if field_shift
        else
          page << "$('#to_first').val('#{j_str(params[:from_first])}');"
          page << javascript_focus('from_second') if params[:from_first].length == 3
        end
      elsif params[:from_second]
        if params[:from_second] =~ /[\D]/
          temp = params[:from_second].gsub(/[\.]/,"")
          field_shift = true if params[:from_second] =~ /[\.]/ && params[:from_second].gsub(/[\.]/,"") =~ /[0-9]/ && temp.gsub!(/[\D]/,"").nil?
          page << "$('#from_second').val('#{j_str(params[:from_second].gsub(/[\D]/, ""))}');"
          page << javascript_focus('from_third') if field_shift
        else
          page << "$('#to_second').val('#{j_str(params[:from_second])}');"
          page << javascript_focus('from_third') if params[:from_second].length == 3
        end
      elsif params[:from_third]
        if params[:from_third] =~ /[\D]/
          temp = params[:from_third].gsub(/[\.]/,"")
          field_shift = true if params[:from_third] =~ /[\.]/ && params[:from_third].gsub(/[\.]/,"") =~ /[0-9]/ && temp.gsub!(/[\D]/,"").nil?
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
      if request.parameters[:controller] == "ems_cloud" || (params[:discover_type_ipmi] && params[:discover_type_ipmi].to_s == "1")
        @ipmi = true
        page << javascript_show("discover_credentials")
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

    klass.find_all_by_id(elements, :order => order_field == "ems_id" ? order_field : "lower(#{order_field})").each do |elem|
      id          = elem.id
      description = get_record_display_name(elem)
      name        = elem.send(order_field.to_sym)
      if task == "destroy"
        audit = { :event        => "#{klass.name.downcase}_record_delete",
                  :message      => "[#{name}] Record deleted",
                  :target_id    => id,
                  :target_class => klass.base_class.name,
                  :userid       => session[:userid]}
      end

      model_name = ui_lookup(:model=>klass.name)  # Lookup friendly model name in dictionary
      begin
        elem.send(task.to_sym) if elem.respond_to?(task)    # Run the task
      rescue StandardError => bang
        add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model=>model_name, :name=>description, :task=>(display_name || task)} << bang.message,
                  :error)
      else
        if task == "destroy"
          AuditEvent.success(audit)
          add_flash(_("%{model} \"%{name}\": Delete successful") % {:model=>model_name, :name=>description})
        else
          add_flash(_("%{model} \"%{name}\": %{task} successfully initiated") % {:model=>model_name, :name=>description, :task=>(display_name || task)})
        end
      end
    end
  end

  private ############################

  # find the record that was chosen
  def identify_record(id, klass = self.class.model)
    begin
      record = find_by_id_filtered(klass, from_cid(id))
    rescue ActiveRecord::RecordNotFound
    rescue StandardError => @bang
      if @explorer
        self.x_node = "root"
        add_flash(@bang.message, :error, true)
        session[:flash_msgs] = @flash_array.dup
      end
    end
    record
  end

  def process_show_list(options={})
    session["#{self.class.session_key_prefix}_display".to_sym] = nil
    @display  = nil
    @lastaction  = "show_list"
    @gtl_url = "/#{self.class.table_name}/show_list/?"

    model = options.delete(:model) # Get passed in model override
    @view, @pages = get_view(model || self.class.model, options)  # Get the records (into a view) and the paginator
    if session[:bc] && session[:menu_click]               # See if we came from a perf chart menu click
      drop_breadcrumb( {:name => session[:bc],
                        :url  => url_for(:controller => self.class.table_name,
                                         :action     => "show_list",
                                         :bc         => session[:bc],
                                         :sb_controller=>params[:sb_controller],
                                         :menu_click => session[:menu_click],
                                         :escape     => false)
                        } )
    else
      @breadcrumbs = Array.new
      bc_name = breadcrumb_name
      bc_name += " - " + session["#{self.class.session_key_prefix}_type".to_sym].titleize if session["#{self.class.session_key_prefix}_type".to_sym]
      bc_name += " (filtered)" if @filters && (!@filters[:tags].blank? || !@filters[:cats].blank?)
      action = %w(container service vm_cloud vm_infra vm_or_template).include?(self.class.table_name) ? "explorer" : "show_list"
      drop_breadcrumb( { :name => bc_name, :url => "/#{self.class.table_name}/#{action}"} )
    end
    @layout = session["#{self.class.session_key_prefix}_type".to_sym] if session["#{self.class.session_key_prefix}_type".to_sym]
    @current_page = @pages[:current] unless @pages.nil? # save the current page number
    build_listnav_search_list(@view.db) if !["miq_task"].include?(@layout) && !session[:menu_click]
    # Came in from outside show_list partial
    unless params[:action] == "explorer"
      if params[:action] != "button" && (params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice])
        replace_gtl_main_div
      end
    end
  end

  def breadcrumb_name
    ui_lookup_for_model(self.class.model_name).pluralize
  end

  # Reconfigure selected VMs
  def reconfigurevms
    assert_privileges(params[:pressed])
    @edit = Hash.new
    @edit[:key] = "reconfigure__new"
    @edit[:current] = Hash.new
    @edit[:new] = Hash.new
    # check to see if coming from show_list or drilled into vms from another CI
    rec_cls = "vm"
    recs = Array.new
    # if coming in to edit from miq_request list view
    if !session[:checked_items].nil? && (@lastaction == "set_checked_items" || params[:pressed] == "miq_request_edit")
      @edit[:req_id] = params[:id]
      recs = session[:checked_items]
    elsif !params[:id] || params[:pressed] == 'vm_reconfigure'
      recs = find_checked_items
    end
    if recs.blank?
      recs = [params[:id].to_i]
    end
    if recs.length < 1
      add_flash(_("One or more %{model} must be selected to %{task}") % {:model=>Dictionary::gettext(db.to_s, :type=>:model, :notfound=>:titleize).pluralize, :task=>"Reconfigure"}, :error)
      render_flash { |page| page << '$(\'#main_div\').scrollTop();' }
      return
    else
      if VmOrTemplate.includes_template?(recs)
        add_flash(_("%{task} does not apply because you selected at least one %{model}") % {:model=>ui_lookup(:table => "miq_template"), :task=>"Reconfigure"}, :error)
        render_flash { |page| page << '$(\'#main_div\').scrollTop();' }
        return
      end
      @edit[:reconfigure_items] = Array.new # Set the array of set ownership items
      recs.each do |r|
        @edit[:reconfigure_items].push(r.to_i)
      end
    end
    if @explorer
      reconfigure
      @edit[:explorer] = true
      session[:changed] = true  #need to enable submit button when screen loads
      @refresh_partial = "vm_common/reconfigure"
    else
      render :update do |page|
        if role_allows(:feature=>"vm_reconfigure")
          page.redirect_to :controller=>"#{rec_cls}", :action => 'reconfigure'              # redirect to build the ownership screen
        end
      end
    end
  end
  alias image_reconfigure reconfigurevms
  alias instance_reconfigure reconfigurevms
  alias vm_reconfigure reconfigurevms
  alias miq_template_reconfigure reconfigurevms

  def set_memory_cpu
    #set memory to nil if multiple items were selected with different mem_cpu values
    @reconfigureitems.each_with_index do |vm, i|
      @temp_memory = i == 0 || @temp_memory == vm.mem_cpu ? vm.mem_cpu : nil
      @temp_cpu_count = i == 0 || @temp_cpu_count == vm.num_cpu ? vm.num_cpu : nil
    end
    @edit[:new][:old_memory], @edit[:new][:old_mem_typ] = reconfigure_calculations(@temp_memory)
    @edit[:new][:old_cpu_count] = @edit[:new][:cpu_count] = @temp_cpu_count
  end

  # Build the ownership assignment screen
  def reconfigure_build_screen
    @reconfigureitems = Vm.find(@edit[:reconfigure_items]).sort_by(&:name)  # Get the db records that are being tagged
    if !@edit[:req_id]
      set_memory_cpu
      @edit[:new][:memory] = @edit[:new][:old_memory]
      @edit[:new][:mem_typ] = @edit[:new][:old_mem_typ]
    else
      @req = MiqRequest.find_by_id(@edit[:req_id])
      @edit[:new][:memory], @edit[:new][:mem_typ] = reconfigure_calculations(@req.options[:vm_memory]) if @req.options[:vm_memory]
      @edit[:new][:cpu_count] = @req.options[:number_of_cpus]
    end

    @edit[:new][:cb_memory] = @req && @req.options[:vm_memory] ? true : false       # default for checkbox is false for new request
    @edit[:new][:cb_cpu] = @req && @req.options[:number_of_cpus] ? true : false     # default for checkbox is false for new request

    @edit[:options] = VmReconfigureRequest.request_limits({:src_ids=>@edit[:reconfigure_items]})
    mem1, fmt1 = reconfigure_calculations(@edit[:options][:min__vm_memory])
    mem2, fmt2 = reconfigure_calculations(@edit[:options][:max__vm_memory])
    @edit[:memory_note] = "Between #{mem1}#{fmt1} and #{mem2}#{fmt2}"

    @edit[:cpu_options] = Array.new
    @edit[:options][:max__number_of_cpus].times do |tidx|
      idx = tidx + @edit[:options][:min__number_of_cpus]
      @edit[:cpu_options].push(idx) if idx <= @edit[:options][:max__number_of_cpus]
    end

    @force_no_grid_xml   = true
    @view, @pages = get_view(Vm, :view_suffix=>"VmReconfigureRequest", :where_clause=>["vms.id IN (?)",@edit[:reconfigure_items]])  # Get the records (into a view) and the paginator

  end

  def reconfigure_calculations(memory)
    if memory.to_i > 1024 && memory.to_i%1024 == 0
      mem = memory.to_i/1024
      fmt = "GB"
    else
      mem = memory
      fmt = "MB"
    end
    return mem.to_s, fmt
  end

  def reconfigure_get_form_vars
    @edit[:new][:cb_memory] = params[:cb_memory] == "1" if params[:cb_memory]
    @edit[:new][:cb_cpu] = params[:cb_cpu] == "1" if params[:cb_cpu]
    @edit[:new][:mem_typ] = params[:mem_typ] if params[:mem_typ]
    @edit[:new][:memory] = params[:memory] if params[:memory]
    @edit[:new][:cpu_count] = params[:cpu_count] if params[:cpu_count]
  end

  # Common VM button handler routines
  def vm_button_operation(method, display_name, partial_after_single_selection = nil)
    vms = Array.new

    # Either a list or coming from a different controller (eg from host screen, go to its vms)
    if @lastaction == "show_list" ||
       !["vm_cloud","vm_infra","vm","miq_template","vm_or_template","service"].include?(request.parameters["controller"]) # showing a list

      vms = find_checked_items
      if method == 'retire_now' && VmOrTemplate.includes_template?(vms)
        add_flash(_("%{task} does not apply to selected %{model}") % {:model=>ui_lookup(:table => "miq_template"), :task=>"Retire"}, :error)
        render_flash { |page| page << '$(\'#main_div\').scrollTop();' }
        return
      end

      if vms.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>request.parameters["controller"]), :task=>display_name}, :error)
      else
        if request.parameters["controller"] == "service"
          process_services(vms, method)
        else
          process_vms(vms, method, display_name)
        end
      end

      if @lastaction == "show_list" # In vm controller, refresh show_list, else let the other controller handle it
        show_list unless @explorer
        @refresh_partial = "layouts/gtl"
      end

    else # showing 1 vm
      klass = get_rec_cls
      if params[:id].nil? || klass.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:table=>request.parameters["controller"]), :error)
        show_list unless @explorer
        @refresh_partial = "layouts/gtl"
      else
        vms.push(params[:id])
        if request.parameters["controller"] == "service"
          process_services(vms, method) unless vms.empty?
        else
          process_vms(vms, method, display_name) unless vms.empty?
        end

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

    return vms.count
  end

  def get_rec_cls
    case request.parameters["controller"]
    when "miq_template"
      return MiqTemplate
    when "service"
      return Service
    else
      return VmOrTemplate
    end
  end

  def process_vms(vms, task, display_name = nil)
    begin
      unless VmOrTemplate::POWER_OPS.include?(task)
        vms, = filter_ids_in_region(vms, "VM")
        return if vms.empty?
      end

      options = {:ids=>vms, :task=>task, :userid => session[:userid]}
      options[:snap_selected] = session[:snap_selected] if task == "remove_snapshot" || task == "revert_to_snapshot"
      kls = VmOrTemplate.find_by_id(vms.first).class.base_model
      Vm.process_tasks(options)
    rescue StandardError => bang                            # Catch any errors
      add_flash(_("Error during '%s': ") % task << bang.message, :error)
    else
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task => display_name ? display_name.titleize : Dictionary::gettext(task, :type=>:task).titleize, :count_model=>pluralize(vms.length,ui_lookup(:model=>kls.to_s))})
    end
  end

  def process_services(services, task)
    begin
      services, services_out_region = filter_ids_in_region(services, "Service")
      return if services.empty?

      options = {:ids=>services, :task=>task, :userid => session[:userid]}
      kls = Service.find_by_id(services.first).class.base_model
      Service.process_tasks(options)
    rescue StandardError => bang                            # Catch any errors
      add_flash(_("Error during '%s': ") % task << bang.message, :error)
    else
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>Dictionary::gettext(task, :type=>:task).titleize, :count_model=>pluralize(services.length,ui_lookup(:model=>kls.to_s))})
    end
  end

  def foreman_button_operation(method, display_name)
    items = []
    if params[:id]
      if params[:id].nil? || ExtManagementSystem.exists?(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:table => controller_name), :error)
      else
        items.push(params[:id])
        @single_delete = true if method == 'destroy' && !flash_errors?
      end
    else
      items = find_checked_items
      if items.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model => ui_lookup(:ui_title => 'foreman'),
                                                                :task  => display_name}, :error)
      else
        process_foreman(items, method) unless items.empty? && !flash_errors?
      end
    end
  end

  def process_foreman(providers, task)
    providers, _services_out_region = filter_ids_in_region(providers, "ConfigurationManagerForeman")
    return if providers.empty?

    options = {:ids => providers, :task => task, :userid => session[:userid]}
    kls = ConfigurationManagerForeman.find_by_id(providers.first).class.base_model
    ConfigurationManagerForeman.process_tasks(options)
    rescue StandardError => bang                            # Catch any errors
      add_flash(_("Error during '%s': ") % task << bang.message, :error)
  else
    add_flash(_("%{task} initiated for %{count_model} (%{controller}) from the CFME Database") %
      {:task        => Dictionary.gettext(task, :type => :task).titleize.gsub("Ems",
                                                                              "#{ui_lookup(:ui_title => 'foreman')}"),
       :controller  => ui_lookup(:ui_title => 'foreman'),
       :count_model => pluralize(providers.length, ui_lookup(:model => kls.to_s))})
  end

  # Delete all selected or single displayed VM(s)
  def deletevms
    assert_privileges(params[:pressed])
    vm_button_operation('destroy', 'deletion')
  end
  alias image_delete deletevms
  alias instance_delete deletevms
  alias vm_delete deletevms
  alias miq_template_delete deletevms

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
  alias image_refresh refreshvms
  alias instance_refresh refreshvms
  alias vm_refresh refreshvms
  alias miq_template_refresh refreshvms

  # Import info for all selected or single displayed vm(s)
  def scanvms
    assert_privileges(params[:pressed])
    vm_button_operation('scan', 'SmartState Analysis')
  end
  alias image_scan scanvms
  alias instance_scan scanvms
  alias vm_scan scanvms
  alias miq_template_scan scanvms

  # Immediately retire VMs
  def retirevms_now
    assert_privileges(params[:pressed])
    vm_button_operation('retire_now', 'retire')
  end
  alias image_retire_now retirevms_now
  alias instance_retire_now retirevms_now
  alias vm_retire_now retirevms_now
  alias service_retire_now retirevms_now

  def check_compliance_vms
    assert_privileges(params[:pressed])
    vm_button_operation('check_compliance_queue', 'check compliance')
  end
  alias image_check_compliance check_compliance_vms
  alias instance_check_compliance check_compliance_vms
  alias vm_check_compliance check_compliance_vms
  alias miq_template_check_compliance check_compliance_vms

  # Collect running processes for all selected or single displayed vm(s)
  def getprocessesvms
    assert_privileges(params[:pressed])
    vm_button_operation('collect_running_processes', 'Collect Running Processes')
  end
  alias instance_collect_running_processes getprocessesvms
  alias vm_collect_running_processes getprocessesvms

  # Start all selected or single displayed vm(s)
  def startvms
    assert_privileges(params[:pressed])
    vm_button_operation('start', 'start')
  end
  alias instance_start startvms
  alias vm_start startvms

  # Suspend all selected or single displayed vm(s)
  def suspendvms
    assert_privileges(params[:pressed])
    vm_button_operation('suspend', 'suspend')
  end
  alias instance_suspend suspendvms
  alias vm_suspend suspendvms

  # Pause all selected or single displayed vm(s)
  def pausevms
    assert_privileges(params[:pressed])
    vm_button_operation('pause', 'pause')
  end

  # Terminate all selected or single displayed vm(s)
  def terminatevms
    assert_privileges(params[:pressed])
    vm_button_operation('vm_destroy', 'terminate')
  end
  alias instance_terminate terminatevms

  # Stop all selected or single displayed vm(s)
  def stopvms
    assert_privileges(params[:pressed])
    vm_button_operation('stop', 'stop')
  end
  alias instance_stop stopvms
  alias vm_stop stopvms

  # Reset all selected or single displayed vm(s)
  def resetvms
    assert_privileges(params[:pressed])
    vm_button_operation('reset', 'reset')
  end
  alias instance_reset resetvms
  alias vm_reset resetvms

  # Shutdown guests on all selected or single displayed vm(s)
  def guestshutdown
    assert_privileges(params[:pressed])
    vm_button_operation('shutdown_guest', 'shutdown')
  end
  alias instance_guest_shutdown guestshutdown
  alias vm_guest_shutdown guestshutdown

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
  alias instance_guest_restart guestreboot
  alias vm_guest_restart guestreboot

  # Delete all snapshots for vm(s)
  def deleteallsnapsvms
    assert_privileges(params[:pressed])
    vm_button_operation('remove_all_snapshots', 'delete all snapshots', 'vm_common/config')
  end
  alias vm_snapshot_delete_all deleteallsnapsvms

  # Delete selected snapshot for vm
  def deletesnapsvms
    assert_privileges(params[:pressed])
    vm_button_operation('remove_snapshot', 'delete snapshot', 'vm_common/config')
  end
  alias vm_snapshot_delete deletesnapsvms

  # Delete selected snapshot for vm
  def revertsnapsvms
    assert_privileges(params[:pressed])
    vm_button_operation('revert_to_snapshot', 'revert to a snapshot', 'vm_common/config')
  end
  alias vm_snapshot_revert revertsnapsvms

  # Policy simulation for selected VMs
  def polsimvms
    assert_privileges(params[:pressed])
    vms = Array.new
    vms = find_checked_items
    if vms.blank?
      vms = [params[:id]]
    end
    if vms.length < 1
      add_flash(_("At least %{num} %{model} must be selected for %{action}") % {:num=>1, :model=>ui_lookup(:model=>"vm"), :action=>"Policy Simulation"}, :error)
      @refresh_div = "flash_msg_div"
      @refresh_partial = "layouts/flash_msg"
    else
      session[:tag_items] = vms       # Set the array of tag items
      session[:tag_db] = VmOrTemplate # Remember the DB
      if @explorer
        @edit ||= Hash.new
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
  alias image_policy_sim polsimvms
  alias instance_policy_sim polsimvms
  alias vm_policy_sim polsimvms
  alias miq_template_policy_sim polsimvms

  #End of common VM button handler routines

  # Common Cluster button handler routines
  def process_clusters(clusters, task)
    clusters, clusters_out_region = filter_ids_in_region(clusters, "Cluster")
    return if clusters.empty?

    if task == "destroy"
      EmsCluster.find_all_by_id(clusters, :order => "lower(name)").each do |cluster|
        id = cluster.id
        cluster_name = cluster.name
        audit = {:event=>"ems_cluster_record_delete_initiated", :message=>"[#{cluster_name}] Record delete initiated", :target_id=>id, :target_class=>"EmsCluster", :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      EmsCluster.destroy_queue(clusters)
    else
      EmsCluster.find_all_by_id(clusters, :order => "lower(name)").each do |cluster|
        id = cluster.id
        cluster_name = cluster.name
        begin
          cluster.send(task.to_sym) if cluster.respond_to?(task)    # Run the task
        rescue StandardError => bang
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model=>ui_lookup(:model=>"EmsCluster"), :name=>cluster_name, :task=>task} << bang.message, :error)  # Push msg and error flag
        else
          add_flash(_("%{model}: %{task} successfully initiated") % {:model=>ui_lookup(:model=>"EmsCluster"), :task=>task})
        end
      end
    end
  end

  # Common RP button handler routines
  def process_resourcepools(rps, task)
    rps, rps_out_region = filter_ids_in_region(rps, "Resource Pool")
    return if rps.empty?

    if task == "destroy"
      ResourcePool.find_all_by_id(rps, :order => "lower(name)").each do |rp|
        id = rp.id
        rp_name = rp.name
        audit = {:event=>"rp_record_delete_initiated", :message=>"[#{rp_name}] Record delete initiated", :target_id=>id, :target_class=>"ResourcePool", :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      ResourcePool.destroy_queue(rps)
    else
      ResourcePool.find_all_by_id(rps, :order => "lower(name)").each do |rp|
        id = rp.id
        rp_name = rp.name
        begin
          rp.send(task.to_sym) if rp.respond_to?(task)    # Run the task
        rescue StandardError => bang
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model=>ui_lookup(:model=>"ResourcePool"), :name=>rp_name, :task=>task} << bang.message, :error) # Push msg and error flag
        else
          add_flash(_("%{model} \"%{name}\": %{task} successfully initiated") % {:model=>ui_lookup(:model=>"ResourcePool"), :name=>rp_name, :task=>task})
        end
      end
    end
  end

  def cluster_button_operation(method, display_name)
    clusters = Array.new

    # Either a list or coming from a different controller (eg from host screen, go to its clusters)
    if @lastaction == "show_list" || @layout != "ems_cluster"
      clusters = find_checked_items
      if clusters.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>"ems_clusters"), :task=>display_name}, :error)
      else
        process_clusters(clusters, method)
      end

      if @lastaction == "show_list" # In cluster controller, refresh show_list, else let the other controller handle it
        show_list
        @refresh_partial = "layouts/gtl"
      end

    else # showing 1 cluster
      if params[:id].nil? || EmsCluster.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:tables=>"ems_cluster"), :error)
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

    return clusters.count
  end

  # Scan all selected or single displayed cluster(s)
  def scanclusters
    assert_privileges("ems_cluster_scan")
    cluster_button_operation('scan', 'Analysis')
  end

  # Common Host button handler routines
  def process_hosts(hosts, task, display_name = nil)
    hosts, hosts_out_region = filter_ids_in_region(hosts, "Host")
    return if hosts.empty?

    if task == "refresh_ems"
      Host.refresh_ems(hosts)
#      add_flash("'" + task.titleize + "' initiated for " + pluralize(hosts.length,"Host"))
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>(display_name || Dictionary::gettext(task, :type=>:task).titleize), :count_model=>pluralize(hosts.length,"Host")})
      AuditEvent.success(:userid=>session[:userid],:event=>"host_#{task}",
          :message=>"'#{display_name || task}' successfully initiated for #{pluralize(hosts.length,"Host")}",
          :target_class=>"Host")
    elsif task == "destroy"
      Host.find_all_by_id(hosts, :order => "lower(name)").each do |host|
        id = host.id
        host_name = host.name
        audit = {:event=>"host_record_delete_initiated", :message=>"[#{host_name}] Record delete initiated", :target_id=>id, :target_class=>"Host", :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      Host.destroy_queue(hosts)
    else
      Host.find_all_by_id(hosts, :order => "lower(name)").each do |host|
        id = host.id
        host_name = host.name
        begin
          if host.respond_to?(task)  # Run the task
            if task == "scan"
              host.send(task.to_sym, session[:userid]) # Scan needs userid
            else
              host.send(task.to_sym)          # Run the task
            end
         end
        rescue StandardError => bang
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model=>ui_lookup(:model=>"Host"), :name=>host_name, :task=>(display_name || task)} << bang.message, :error) # Push msg and error flag
        else
          add_flash(_("\"%{record}\": %{task} successfully initiated") % {:record=>host_name, :task=>(display_name || task)})
        end
      end
    end
  end

  # Common Stacks button handler routines
  def process_orchestration_stacks(stacks, task, _ = nil)
    stacks, _ = filter_ids_in_region(stacks, "OrchestrationStack")
    return if stacks.empty?

    if task == "destroy"
      OrchestrationStack.find_all_by_id(stacks, :order => "lower(name)").each do |stack|
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
    host_button_operation('refresh_ems', 'Refresh')
  end

  # Scan all selected or single displayed host(s)
  def scanhosts
    assert_privileges("host_scan")
    host_button_operation('scan', 'Analysis')
  end

  def check_compliance_hosts
    assert_privileges("host_check_compliance")
    host_button_operation('check_compliance_queue', 'Compliance Check')
  end

  def analyze_check_compliance_hosts
    assert_privileges("host_analyze_check_compliance")
    host_button_operation('scan_and_check_compliance_queue', 'Analyze and Compliance Check')
  end

  # Handle the Host power buttons
  POWER_BUTTON_NAMES = {
    "reboot"            => "Restart",
    "start"             => "Power On",
    "stop"              => "Power Off",
    "enter_maint_mode"  => "Enter Maintenance Mode",
    "exit_maint_mode"   => "Exit Maintenance Mode",
    "standby"           => "Shutdown to Standby Mode"
  }
  def powerbutton_hosts(method)
    assert_privileges(params[:pressed])
    host_button_operation(method, POWER_BUTTON_NAMES[method] || method.titleize)
  end

  def host_button_operation(method, display_name)
    hosts = Array.new

    # Either a list or coming from a different controller (eg from ems screen, go to its hosts)
    if @lastaction == "show_list" || @layout != "host"
      hosts = find_checked_items
      if hosts.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>"host"), :task=>display_name}, :error)
      else
        process_hosts(hosts, method, display_name)
      end

      if @lastaction == "show_list" # In host controller, refresh show_list, else let the other controller handle it
        show_list
        @refresh_partial = "layouts/gtl"
      end

    else # showing 1 host
      if params[:id].nil? || Host.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:table=>"host"), :error)
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

    return hosts.count
  end

  def process_storage(storages, task)
    storages, storages_out_region = filter_ids_in_region(storages, "Datastore")
    return if storages.empty?

    if task == "destroy"
      Storage.find_all_by_id(storages, :order => "lower(name)").each do |storage|
        id = storage.id
        storage_name = storage.name
        audit = {:event=>"storage_record_delete_initiated", :message=>"[#{storage_name}] Record delete initiated", :target_id=>id, :target_class=>"Storage", :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      Storage.destroy_queue(storages)
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Delete", :count_model=>pluralize(storages.length,"Datastore")})
    else
      Storage.find_all_by_id(storages, :order => "lower(name)").each do |storage|
        id = storage.id
        storage_name = storage.name
        begin
          if task == "scan"
            storage.send(task.to_sym, session[:userid]) # Scan needs userid
          else
            storage.send(task.to_sym) if storage.respond_to?(task)    # Run the task
          end
        rescue StandardError => bang
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model=>ui_lookup(:model=>"Storage"), :name=>storage_name, :task=>task} << bang.message, :error) # Push msg and error flag
        else
          if task == "refresh_ems"
            add_flash(_("\"%{record}\": %{task} successfully initiated") % {:record=>storage_name, :task=>"Refresh"})
          else
            add_flash(_("\"%{record}\": %{task} successfully initiated") % {:record=>storage_name, :task=>task})
          end
        end
      end
    end
  end

  def storage_button_operation(method, display_name)
    storages = Array.new

    # Either a list or coming from a different controller (eg from host screen, go to its storages)
    if @lastaction == "show_list" || @layout != "storage"
      storages = find_checked_items
      if storages.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>"storage"), :task=>display_name}, :error)
      else
        process_storage(storages, method)
      end

      if @lastaction == "show_list" # In storage controller, refresh show_list, else let the other controller handle it
        show_list
        @refresh_partial = "layouts/gtl"
      end

    else # showing 1 storage
      if params[:id].nil? || Storage.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:tables=>"storage"), :error)
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

    return storages.count
  end

  # Refresh all selected or single displayed Datastore(s)
  def refreshstorage
    assert_privileges("storage_refresh")
    storage_button_operation('refresh_ems', 'Refresh')
  end

  # Scan all selected or single displayed storage(s)
  def scanstorage
    assert_privileges("storage_scan")
    storage_button_operation('scan', 'Analysis')
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
    datastores = Array.new
    if @lastaction == "show_list" || (@lastaction == "show" && @layout != "storage")  # showing a list, scan all selected hosts
      datastores = find_checked_items
      if datastores.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>"storage"), :task=>display_name}, :error)
      end
      ds_to_delete = Array.new
      datastores.each do |s|
        ds = Storage.find_by_id(s)
        if ds.vms_and_templates.length <= 0 && ds.hosts.length <= 0
          ds_to_delete.push(s)
        else
          add_flash(_("\"%s\": cannot be removed, has vms or hosts") % ds.name, :warning)
        end
      end
      process_storage(ds_to_delete, "destroy")  if !ds_to_delete.empty?
    else # showing 1 datastore, delete it
      if params[:id] == nil || Storage.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:tables=>"storage"), :error)
      else
        datastores.push(params[:id])
      end
      process_storage(datastores, "destroy")  if ! datastores.empty?
      @single_delete = true unless flash_errors?
      add_flash(_("The selected %s was deleted") % ui_lookup(:table=>"storages")) if @flash_array == nil
    end
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    end
  end

  def delete_elements(model_class, destroy_method)
    elements = Array.new
    if @lastaction == "show_list" || (@lastaction == "show" && @layout != model_class.table_name.singularize)  # showing a list
      elements = find_checked_items
      if elements.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:tables=>model_class.table_name), :task=>"deletion"}, :error)
      end
      self.send(destroy_method, elements, "destroy") unless elements.empty?
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Delete", :count_model=>pluralize(elements.length,ui_lookup(:table=>model_class.table_name))}) unless flash_errors?
    else # showing 1 element, delete it
      if params[:id] == nil || model_class.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:table=>model_class.table_name), :error)
      else
        elements.push(params[:id])
      end
      self.send(destroy_method, elements, "destroy") unless elements.empty?
      @single_delete = true unless flash_errors?
      add_flash(_("The selected %s was deleted") % ui_lookup(:table=>model_class.table_name)) if @flash_array.nil?
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

  # Go thru the view rows, collect picture object ids, and call sync_to_disk
  def sync_view_pictures_to_disk(view)
    pics = view.table.data.collect{|r| r["picture.id"].to_i if r["picture.id"]}.compact.uniq
#    Picture.sync_to_disk(pics) unless pics.blank?
    add_pictures_to_sync(pics) unless pics.blank?
  end

  def pfx_for_vm_button_pressed(button_pressed)
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
        while meth = method.shift do
          obj = obj.send(meth)
        end
        @item = obj.find(from_cid(id))
      else
        @item = @record.send(method).find(from_cid(id))
      end

      drop_breadcrumb({:name => "#{@record.name} (#{display_name})",
                       :url => "/#{controller_name}/#{action}/#{@record.id}?page=#{@current_page}"})
      drop_breadcrumb(:name => @item.name,
                      :url => "/#{controller_name}/#{action}/#{@record.id}?show=#{@item.id}")
      @view = get_db_view(klass, :association=>association)
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
