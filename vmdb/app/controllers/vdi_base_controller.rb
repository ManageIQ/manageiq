class VdiBaseController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter  :cleanup_action
  after_filter  :set_session_data

  def assign_form_field_changed
    return unless load_edit("assign_edit__new")
    assign_get_form_vars
    changed = (@edit[:new] != @edit[:current])
    render :update do |page|                    # Use JS to update the display
      page << javascript_for_miq_button_visibility(changed)
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg") if @flash_array
      page.replace(@refresh_div, :partial=>"shared/views/vdi_common/#{@refresh_partial}") if @refresh_div
      page << "miqSparkle(false);"
      page
    end
  end

  # Build the retire VMs screen
  def assign
    #reusing same code to set vars when buttons are pressed on sub-list views or from direct list/show screens
    if (request.parameters[:controller] == "vdi_user" && (!@display || @display == "main")) || @display == "vdi_user"
      controller = "vdi_user"
    else
      controller = "vdi_desktop_pool"
    end
    case params[:button]
      when "cancel"
        flash = I18n.t("flash.edit.user_assignment_cancelled")
        if session[:selected_items].length == 1 && @lastaction == "show"
          redirect_to :controller=>controller, :action=>@lastaction, :id=>session[:selected_items][0], :flash_msg=>flash, :escape=>false
        else
          #setting lastaction to show_list in case button was pressed from sub-list view
          @lastaction = "show_list" if @display
          redirect_to :controller=>controller, :action=>@lastaction, :flash_msg=>flash, :escape=>false
        end
        return
      when "save"
        return unless load_edit("assign_edit__new")
        assign_get_form_vars
        #items to be assigned to selected_items
        assign_items = assign_set_record_vars
        if (request.parameters[:controller] == "vdi_user" && (!@display || @display == "main")) || @display == "vdi_user"
          VdiDesktopPool.assign_users(assign_items, session[:selected_items])
        else
          VdiDesktopPool.assign_users(session[:selected_items], assign_items)
        end
        #if any of the items were moved to left editing single record unassign them
        if session[:selected_items].length == 1 && @edit[:new][:available_items] != @edit[:current][:available_items]
          #items to be unassigned from selected_items
          items = unassign_set_record_vars
          unless items.blank?
            if (request.parameters[:controller] == "vdi_user" && (!@display || @display == "main")) || @display == "vdi_user"
              VdiDesktopPool.unassign_users(items,session[:selected_items])
            else
              VdiDesktopPool.unassign_users(session[:selected_items], items)
            end
          end
        end
        flash = I18n.t("flash.edit.user_assignment_initiated")
        if session[:selected_items].length == 1 && @lastaction == "show"
          redirect_to :controller=>controller, :action=>@lastaction, :id=>session[:selected_items][0], :flash_msg=>flash, :flash_error=>@error, :escape=>false
        else
          #setting lastaction to show_list in case button was pressed from sub-list view
          @lastaction = "show_list" if @display
          redirect_to :controller=>controller, :action=>@lastaction, :flash_msg=>flash, :flash_error=>@error, :escape=>false
        end
        return
      else
        add_flash(I18n.t("flash.edit.reset"), :warning) if params[:button] == "reset"
        @gtl_url = "/shared/views/vdi_common/assign?"
        title = @lastaction == "show" ? "Manage VDI User assignments" : "Assign VDI Users to Desktop Pools"
        drop_breadcrumb( {:name=>title, :url=>"/shared/views/vdi_common/assign"} )
        assign_build_screen
        @edit[:current] = copy_hash(@edit[:new])
        session[:edit] = @edit
        @in_a_form = true
        render :action=>"show"
    end
  end

  private

  def unmark_vdi
    assert_privileges("vdi_desktop_unmark_vdi")
    unless params[:task_id]                       # First time thru
      @sb[:items] = Array.new
      if @lastaction == "show_list" || (@lastaction == "show" && @display == "vdi_desktop") # showing a list of Desktops
        @sb[:items] = find_checked_items
        if @sb[:items].empty?
          add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:models=>"VdiDesktop"), :task=>"Unmark"), :error)
        end
      else # showing 1 vdi_farm, scan it
        if params[:id].nil? || VdiDesktop.find_by_id(params[:id]).nil?
          add_flash(I18n.t("flash.record.no_longer_exists", :model=>"VdiDesktop"), :error)
        else
          @sb[:items].push(params[:id])
        end
      end
    end

    unless params[:task_id]                       # First time thru, kick off the report generate task
      initiate_wait_for_task(:task_id => VdiDesktop.queue_mark_as_non_vdi(@sb[:items]))
      return
    end

    @temp[:marked] = true
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

    if @lastaction == "show_list"
      show_list
      replace_gtl_main_div
    else
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|                      # Use JS to update the display
        if @lastaction == "show" && @display == "vdi_desktop" # showing a list of Desktops
          page.redirect_to :action => 'show', :id=>params[:id], :display=>"vdi_desktop", :controller=>request.parameters[:controller]
        else
          page.redirect_to :action => 'show_list'
        end
        page << "miqSparkle(false);"
      end
    end
  end

  def vdi_desktop_pool_delete
    assert_privileges("vdi_desktop_pool_delete")
    items = Array.new
    if @lastaction == "show_list" || (@lastaction == "show" && @display == "vdi_desktop_pool") # showing a list, scan all selected vdi_farms
      items = find_checked_items
      if items.empty?
        add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:models=>"VdiDesktopPool"), :task=>"deletion"), :error)
      end
      VdiDesktopPool.remove_desktop_pools(items)
      add_flash(I18n.t("flash.record.task_initiated_for_model", :task=>"Delete", :count_model=>pluralize(items.length,ui_lookup(:model=>"VdiDesktopPool")))) if @flash_array.nil?
    else # showing 1 vdi_farm, scan it
      if params[:id].nil? || VdiDesktopPool.find_by_id(params[:id]).nil?
        add_flash(I18n.t("flash.record.no_longer_exists", :model=>"VdiDesktopPool"), :error)
      else
        items.push(params[:id])
      end
      VdiDesktopPool.remove_desktop_pools(items)
      @single_delete = true unless flash_errors?
      add_flash(I18n.t("flash.record.delete_for_1_record_initiated", :model=>"VdiDesktopPool")) if @flash_array.nil?
    end
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    end
  end

  def assign_set_record_vars
    #return items that were moved ot the right on the edit screen
    items = Array.new
    @edit[:new][:assigned_items].each do |dp|
      items.push(dp.last)
    end
    return items
  end

  def unassign_set_record_vars
    #return any of the items that wer emoved to left on edit screen
    items = Array.new
    @edit[:current][:assigned_items].each do |dp|
      items.push(dp.last) if !@edit[:new][:assigned_items].include?(dp)
    end
    return items
  end

  def assign_get_form_vars
    if params[:button]
      move_cols_right if params[:button] == "right"
      move_cols_left  if params[:button] == "left"
    end
  end

  def move_cols(direction)
    from = (direction == :left) ? :assigned_items  : :available_items
    to   = (direction == :left) ? :available_items : :assigned_items

    if ! params[from] || params[from].length == 0 || params[from][0] == ""
      add_flash(I18n.t("flash.edit.no_fields_to_move.#{direction}", :field=>"fields"), :error)
    else
      @edit[:new][from].each { |nf| @edit[:new][to].push(nf) if params[from].include?(nf.last.to_s) }
      @edit[:new][from].delete_if { |nf| params[from].include?(nf.last.to_s) }
      @edit[:new][to].sort!
      @edit[:new][from].sort!
      @refresh_div     = "column_lists"
      @refresh_partial = "column_lists"
    end
    @selected = params[from]
  end

  def move_cols_left
    move_cols(:left)
  end

  def move_cols_right
    move_cols(:right)
  end

  # Retire 1 or more VMs
  def user_assignment
    assert_privileges("vdi_desktop_pool_user_assign")
    items = find_checked_items
    if items.blank?
      session[:selected_items] = [params[:id]]
    else
      if items.length < 1
        add_flash(I18n.t("flash.button.at_least_selected", :num=>"one", :model=>ui_lookup(:table=>"vdi_user"), :task=>"assignment"), :error)
        @refresh_div = "flash_msg_div"
        @refresh_partial = "layouts/flash_msg"
        return
      else
        session[:selected_items] = items                                # Set the array of retire items
      end
    end
    render :update do |page|
      page.redirect_to :controller => controller_name, :action => 'assign' # redirect to build the retire screen
    end
  end

  def assign_build_screen
    @edit = Hash.new
    @edit[:key] = "assign_edit__new"
    @edit[:current] = Hash.new
    @edit[:new] = Hash.new
    if (request.parameters[:controller] == "vdi_user" && (!@display || @display == "main")) || @display == "vdi_user"
      kls = VdiUser
    else
      kls = VdiDesktopPool
    end
    @assignitems = kls.find(session[:selected_items]).sort{|a,b| a.name <=> b.name} # Get the db records
    build_targets_hash(@assignitems)
    @view = get_db_view(kls)              # Instantiate the MIQ Report view object
    @view.table = MiqFilter.records2table(@assignitems, :only=>@view.cols + ['id'])
    @edit[:new][:assigned_items] = Array.new
    if (request.parameters[:controller] == "vdi_user" && (!@display || @display == "main")) || @display == "vdi_user"
      if @assignitems.length == 1 && @assignitems[0].vdi_desktop_pools != nil
        @assignitems[0].vdi_desktop_pools.each do |dp|
          @edit[:new][:assigned_items].push([dp.name,dp.id])      # Single User, set despktop pools it's assigned to
        end
      end
      @edit[:new][:available_items] = Array.new
      VdiDesktopPool.user_assignable_pools.each do |dp|
        @edit[:new][:available_items].push([dp.name,dp.id]) if !@edit[:new][:assigned_items].include?([dp.name,dp.id])
      end
    else
      if @assignitems.length == 1 && @assignitems[0].vdi_users != nil
        @assignitems[0].vdi_users.each do |u|
          @edit[:new][:assigned_items].push([u.name,u.id])      # Single User, set despktop pools it's assigned to
        end
      end
      @edit[:new][:available_items] = Array.new
      VdiUser.find(:all).each do |u|
        @edit[:new][:available_items].push([u.name,u.id]) if !@edit[:new][:assigned_items].include?([u.name,u.id])
      end
    end
    @edit[:new][:available_items].sort!
    @edit[:new][:assigned_items].sort!
    @in_a_form = true
  end

  def user_unassign
    assert_privileges("vdi_#{@display == "vdi_user" ? "user_desktop_pool" : "desktop_pool_user"}_unassign")
    params[:display] = @display
    items = find_checked_items
    show
    case @display
      when "vdi_user"
        kls = VdiUser
        users = items
        pools = [@record.id]
      when "vdi_desktop_pool"
        kls = VdiDesktopPool
        pools = items
        users = [@record.id]
    end

    if items.empty?
      add_flash(I18n.t("flash.no_records_selected_for_task", :model=>ui_lookup(:models=>kls.to_s), :task=>"Un-Assignment"), :error)
    else
      VdiDesktopPool.unassign_users(pools,users) unless pools.blank?
      add_flash(I18n.t("flash.edit.user_unassignment_initiated"))
    end
  end

  def process_index
    redirect_to :action => 'show_list'
  end

  def process_show(associations = {})
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype   = "config"
    @record = identify_record(params[:id])
    return if record_no_longer_exists?(@record)
    @gtl_url = "/#{self.class.table_name}/show/#{@record.id.to_s}?"
    if ["download_pdf","main","summary_only"].include?(@display)
      drop_breadcrumb( { :name => ui_lookup(:tables=>self.class.table_name), :url => "/#{self.class.table_name}/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb( { :name => "#{@record.name} (Summary)",               :url => "/#{self.class.table_name}/show/#{@record.id}"} )
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)
    elsif associations.keys.include?(@display)
      table_name =  if @display == "unassigned_vdi_desktop"
                      "VdiDesktop"
                    else
                      whitelisted_key = associations.keys.detect { |k| k == @display }
                      whitelisted_key.singularize
                    end
      model_name = table_name.classify.constantize
      drop_breadcrumb( { :name => "#{@record.name} (All #{ui_lookup(:tables => @display.singularize)})", :url => "/#{self.class.table_name}/show/#{@record.id}?display=#{@display}"} )
      @view, @pages = get_view(model_name, :parent=>@record, :parent_method => associations[@display])  # Get the records (into a view) and the paginator
      @showtype = @display
    end
  end

  def get_session_data
    @title      = ui_lookup(:tables => self.class.table_name)
    @layout     = self.class.table_name
    prefix      = self.class.session_key_prefix
    @lastaction = session["#{prefix}_lastaction".to_sym]
    @showtype   = session["#{prefix}_showtype".to_sym]
    @display    = session["#{prefix}_display".to_sym]
  end

  def set_session_data
    prefix                                 = self.class.session_key_prefix
    session["#{prefix}_lastaction".to_sym] = @lastaction
    session["#{prefix}_showtype".to_sym]   = @showtype
    session["#{prefix}_display".to_sym]    = @display unless @display.nil?
  end

end
