class VdiFarmController < VdiBaseController

  def index
    process_index
  end

  def show
    process_show(
      'vdi_desktop'      => :vdi_desktops,
      'vdi_desktop_pool' => :vdi_desktop_pools,
      'vdi_controller'   => :vdi_controllers,
      'miq_proxies'      => :miq_proxies,
      'vdi_user'         => :vdi_users
    )
  end

  def show_list
    process_show_list
  end

    # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                          # Restore @edit for adv search box
    edit_record  if params[:pressed] == "vdi_farm_edit"
    deletefarms  if params[:pressed] == "vdi_farm_delete"
    refreshfarms if params[:pressed] == "vdi_farm_refresh"
    vdi_desktop_pool_delete if params[:pressed] == "vdi_desktop_pool_delete"
    edit_record if params[:pressed] == "vdi_desktop_pool_new"
    edit_record  if params[:pressed] == "vdi_desktop_pool_edit"
    unmark_vdi if params[:pressed] == "vdi_desktop_unmark_vdi"
    @refresh_div = "main_div" # Default div for button.rjs to refresh

    #no need to render anything, method will render flash message when async task is completed
    return if ["vdi_desktop_unmark_vdi"].include?(params[:pressed])

    if !@flash_array && !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(I18n.t("flash.button.not_implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div     = "flash_msg_div"
    elsif @flash_array && @lastaction == "show"
      @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div     = "flash_msg_div"
    end

    if !@flash_array.nil? && params[:pressed] == "vdi_farm_delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to show_list
      end
    elsif params[:pressed].ends_with?("_edit") || params[:pressed].ends_with?("_new")
      if @redirect_controller
        render :update do |page|
          page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id
        end
      else
        render :update do |page|
          page.redirect_to :action=>@refresh_partial, :id=>@redirect_id
        end
      end
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render :update do |page|                    # Use RJS to update the display
          if @refresh_partial != nil
            if @refresh_div == "flash_msg_div"
              page.replace(@refresh_div, :partial=>@refresh_partial)
            else
              page.replace_html(@refresh_div, :partial=>@refresh_partial)
            end
          end
        end
      end
    end
  end

  def new
    assert_privileges("vdi_farm_new")
    @record = VdiFarm.new
    set_form_vars
    @in_a_form        = true
    session[:changed] = nil
    drop_breadcrumb( {:name =>"Add New #{ui_lookup( :table => self.class.table_name )}", :url=>"/#{self.class.table_name}/new"} )
  end

  def edit
    assert_privileges("vdi_farm_edit")
    @record = find_by_id_filtered(VdiFarm, params[:id])
    set_form_vars
    @in_a_form        = true
    session[:changed] = false
    drop_breadcrumb( {:name=>"Edit #{ui_lookup( :table => self.class.table_name )} '#{@record.name}'", :url=>"/#{self.class.table_name}/edit/#{@record.id}"} )
  end

    # Delete all selected or single displayed vdi_farm(s)
  def deletefarms
    assert_privileges("vdi_farm_delete")
    vdi_farms = Array.new
    if @lastaction == "show_list" # showing a list, scan all selected vdi_farms
      vdi_farms = find_checked_items
      if vdi_farms.empty?
        add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:tables=>self.class.table_name), :task=>"deletion"), :error)
      end
      process_farms(vdi_farms, "destroy") if ! vdi_farms.empty?
      add_flash(I18n.t("flash.record.task_initiated_for_model", :task=>"Delete", :count_model=>pluralize(vdi_farms.length,ui_lookup(:table => self.class.table_name)))) if @flash_array.nil?
    else # showing 1 vdi_farm, scan it
      if params[:id].nil? || VdiFarm.find_by_id(params[:id]).nil?
        add_flash(I18n.t("flash.record.no_longer_exists", :model=>ui_lookup( :table => self.class.table_name )), :error)
      else
        vdi_farms.push(params[:id])
      end
      process_farms(vdi_farms, "destroy") if ! vdi_farms.empty?
      @single_delete = true unless flash_errors?
      add_flash(I18n.t("flash.record.deleted_for_1_record", :model=>ui_lookup(:table => self.class.table_name))) if @flash_array.nil?
    end
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    end
  end

  def refreshfarms
    assert_privileges("vdi_farm_refresh")
    farms = Array.new
    if @lastaction == "show_list" # showing a list, scan all selected emss
      farms = find_checked_items
      if farms.empty?
        add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:tables=>self.class.table_name), :task=>"refresh"), :error)
      end
      process_farms(farms, "refresh_farms") if ! farms.empty?
      add_flash(I18n.t("flash.record.task_initiated_for_model", :task=>"Refresh", :count_model=>pluralize(farms.length,ui_lookup(:tables=>self.class.table_name)))) if @flash_array.nil?
      show_list
      @refresh_partial = "layouts/gtl"
    else # showing 1 ems, scan it
      if params[:id].nil? || VdiFarm.find_by_id(params[:id]).nil?
        add_flash(I18n.t("flash.record.no_longer_exists", :model=>ui_lookup( :table => self.class.table_name )), :error)
      else
        farms.push(params[:id])
      end
      process_farms(farms, "refresh_farms") if ! farms.empty?
      add_flash(I18n.t("flash.record.task_initiated_for_model", :task=>"Refresh", :count_model=>pluralize(farms.length,ui_lookup(:table=>self.class.table_name)))) if @flash_array.nil?
      params[:display] = @display
      show
    end
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("farm_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])

    render :update do |page|                    # Use JS to update the display
      page << javascript_for_miq_button_visibility(changed)
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg") unless @refresh_div && @refresh_div != "proxy_lists"
      page.replace(@refresh_div, :partial=>@refresh_partial) if @refresh_div
      page.replace("form_div", :partial=>"form") if params[:vendor_type]
      page << "miqSparkle(false);"
    end
  end

  def update
    assert_privileges("vdi_farm_edit")
    return unless load_edit("farm_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      add_flash(I18n.t("flash.edit.cancelled", :model=>ui_lookup(:table=>self.class.table_name), :name=>@record.name))
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to :action=>@lastaction, :id=>@record.id, :display=>session[:vdi_farm_display]
      end
    when "save"
      if @edit[:new][:name].nil? || @edit[:new][:name] == ""
        add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error)
      end
      unless @flash_array.nil?
        @in_a_form = true
        drop_breadcrumb( {:name=>"Add New #{ui_lookup( :table => self.class.table_name )}", :url=>"/#{self.class.table_name}/new"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end

      update_vdi_farm = find_by_id_filtered(VdiFarm, params[:id])
      set_record_vars(update_vdi_farm)
      if update_vdi_farm.save
        add_flash(I18n.t("flash.edit.saved", :model=>ui_lookup( :table => self.class.table_name ), :name=>update_vdi_farm.name))
        AuditEvent.success(build_saved_audit(update_vdi_farm, @edit))
        session[:edit] = nil  # clean out the saved info
        show
        session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
        render :update do |page|
          page.redirect_to :action=>'show', :id=>@record.id.to_s
        end
        return
      else
        update_vdi_farm.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        drop_breadcrumb( {:name=>"Edit #{ui_lookup( :table => self.class.table_name )} '#{@edit[:vdi_farm].name}'", :url=>"/#{self.class.table_name}/edit/#{@record.id}"} )
        @in_a_form        = true
        session[:changed] = changed
        @changed          = true
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    when "reset"
      edit
      add_flash(I18n.t("flash.edit.reset"), :warning)
      @in_a_form = true
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to :action=>'edit', :id=>@record.id.to_s
      end
    end
  end

  def create
    assert_privileges("vdi_farm_new")
    return unless load_edit("farm_edit__new")
    get_form_vars
    case params[:button]
    when "cancel"
      msg = I18n.t("flash.add.cancelled", :model=>ui_lookup(:table => self.class.table_name))
      render :update do |page|
        page.redirect_to :action=>'show_list', :flash_msg=>msg
      end
    when "add"
      if @edit[:new][:name].nil? || @edit[:new][:name] == ""
        add_flash(I18n.t("flash.edit.field_required", :field=>"Name"), :error)
      end
      if @flash_array != nil
        @in_a_form = true
        drop_breadcrumb( {:name=>"Add New #{ui_lookup( :table => self.class.table_name )}", :url=>"/#{self.class.table_name}/new"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end

      add_vdi_farm = "VdiFarm#{@edit[:new][:vendor].camelcase}".constantize.new
      set_record_vars(add_vdi_farm)
      if add_vdi_farm.save
        AuditEvent.success(build_created_audit(add_vdi_farm, @edit))
        session[:edit] = nil  # Clear the edit object from the session object
        msg = I18n.t("flash.add.added", :model=>ui_lookup( :table => self.class.table_name), :name=>add_vdi_farm.name)
        render :update do |page|
          page.redirect_to :action=>'show_list', :flash_msg=>msg
        end
      else
        @in_a_form = true
        add_vdi_farm.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        drop_breadcrumb( {:name=>"Add New #{ui_lookup( :table => self.class.table_name )}", :url=>"/#{self.class.table_name}/new"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    end
  end

  private ########

  def move_cols(direction)
    from = (direction == :left) ? :selected_proxies  : :available_proxies
    to   = (direction == :left) ? :available_proxies : :selected_proxies

    if ! params[from] || params[from].length == 0 || params[from][0] == ""
      add_flash(I18n.t("flash.edit.no_fields_to_move.#{direction}", :field=>"fields"), :error)
    else
      @edit[:new][from].each { |nf| @edit[:new][to].push(nf) if params[from].include?(nf) }
      @edit[:new][from].delete_if { |nf| params[from].include?(nf) }
      @edit[:new][to].sort!
      @refresh_div     = "proxy_lists"
      @refresh_partial = "proxy_lists"
    end

  end

  def move_cols_left
    move_cols(:left)
  end

  def move_cols_right
    move_cols(:right)
  end

  # Set form variables for edit
  def set_form_vars
    @edit              = Hash.new
    @edit[:vdi_farm]   = @record
    @edit[:farm_types] = VdiFarm::FARM_TYPES
    @edit[:key]        = "farm_edit__#{@record.id || "new"}"
    @edit[:new]        = Hash.new
    @edit[:current]    = Hash.new

    @edit[:new][:name]             = @record.name
    @edit[:new][:vendor]           = @record.vendor
    @edit[:new][:selected_proxies] = Array.new
    @record.miq_proxies.sort{|a,b|a.name.downcase<=>b.name.downcase}.each do |proxy|
      @edit[:new][:selected_proxies].push(proxy.name)
    end

    @edit[:new][:available_proxies] = Array.new
    VdiFarm.unassigned_miq_proxies.sort{|a,b|a.name.downcase<=>b.name.downcase}.each do |proxy|
      @edit[:new][:available_proxies].push(proxy.name)
    end

    if @record.zone.nil?
      @edit[:new][:zone] = "default"
    else
      @edit[:new][:zone] = @record.zone.name
    end
    @edit[:server_zones] = Array.new
    zones = Zone.all
    zones.each do |zone|
      @edit[:server_zones].push(zone.name)
    end

    @edit[:current] = copy_hash(@edit[:new])
    session[:edit]  = @edit
  end

  # Get variables from edit form
  def get_form_vars
    @record = @edit[:vdi_farm]
    if params[:button]
      move_cols_right if params[:button] == "right"
      move_cols_left  if params[:button] == "left"
    else
      @edit[:new][:name] = params[:name] if params[:name]
      @edit[:new][:vendor] = params[:vendor_type] if params[:vendor_type]
    end
    @edit[:new][:zone] = params[:server_zone] if params[:server_zone]
  end

  # Set record variables to new values
  def set_record_vars(vdi_farm)
    vdi_farm.name   = @edit[:new][:name]
    vdi_farm.vendor = @edit[:new][:vendor]
    miq_proxies     = Array.new
    @edit[:new][:selected_proxies].each do |proxy|
      miq_proxies.push(MiqProxy.find_by_name(proxy))
    end
    vdi_farm.miq_proxies = miq_proxies
    vdi_farm.zone = Zone.find_by_name(@edit[:new][:zone])
  end

  def process_farms(farms, task)
    if task == "refresh_farms"
      VdiFarm.refresh_ems(farms, true)
      add_flash(I18n.t("flash.record.task_initiated_for_model",
          :task=>Dictionary::gettext(task, :type=>:task).titleize.gsub("Ems",ui_lookup( :table => self.class.table_name )),
          :count_model=>pluralize(farms.length,ui_lookup(:table => self.class.table_name))))
      AuditEvent.success(
          :userid       => session[:userid],
          :event        => "#{self.class.table_name}_#{task}",
          :message      => "'#{task}' successfully initiated for #{pluralize(farms.length,ui_lookup( :table => self.class.table_name ))}",
          :target_class =>"VdiFarm"
        )
    elsif task == "destroy"
      VdiFarm.find_all_by_id(farms, :order => "lower(name)").each do |farm|
        id        = farm.id
        farm_name = farm.name
        audit = {
          :event        => "#{self.class.table_name}_record_delete",
          :message      => "[#{farm_name}] Record deleted",
          :target_id    => id,
          :target_class =>"VdiFarm",
          :userid       => session[:userid]
        }
        begin
          farm.send(task.to_sym) if farm.respond_to?(task)    # Run the task
        rescue StandardError => bang
          add_flash(I18n.t("flash.record.error_during_task", :model=>ui_lookup(:model=>"VdiFarm"), :name=>farm_name, :task=>task) << bang.message, :error) # Push msg and error flag
        else
          if task == "destroy"
            AuditEvent.success(audit)
            add_flash(I18n.t("flash.record.deleted", :model=>ui_lookup(:model=>"VdiFarm"), :name=>farm_name))
          else
            add_flash(I18n.t("flash.record.task_initiated_for_record", :record=>farm_name, :task=>task))
          end
        end
      end
    end
  end

end
