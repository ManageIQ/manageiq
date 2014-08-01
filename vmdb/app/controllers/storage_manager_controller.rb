class StorageManagerController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:page] = @current_page if @current_page != nil   # Save current page for list refresh
    @refresh_div = "main_div" # Default div for button.rjs to refresh
    redirect_to :action => "new" if params[:pressed] == "storage_manager_new"
    deletesms if params[:pressed] == "storage_manager_delete"
    edit_record if params[:pressed] == "storage_manager_edit"
    refresh_inventory if params[:pressed] == "storage_manager_refresh_inventory"
    refresh_status_sm if params[:pressed] == "storage_manager_refresh_status"

    if !@flash_array && !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(I18n.t("flash.button.not_implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    elsif @flash_array && @lastaction == "show"
      @sm = @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if !@flash_array.nil? && params[:pressed] == "storage_manager_delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to build the retire screen
      end
    elsif params[:pressed].ends_with?("_edit")
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
    assert_privileges("storage_manager_new")
    @sm = StorageManager.new
    set_form_vars
    @in_a_form = true
    session[:changed] = nil
    drop_breadcrumb( {:name=>"Add New Storage Manager", :url=>"/storage_manager/new"} )
  end

  def create
    assert_privileges("storage_manager_new")
    return unless load_edit("sm_edit__new")
    get_form_vars
    case params[:button]
    when "cancel"
      render :update do |page|
        page.redirect_to :action=>'show_list', :flash_msg=>I18n.t("flash.add.cancelled", :model=>ui_lookup(:table =>"StorageManager"))
      end
    when "add"
      if @edit[:new][:sm_type].nil?
        add_flash(I18n.t("flash.edit.field_required", :field=>"Type"), :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end
      if @edit[:new][:sm_type].nil? || @edit[:new][:sm_type] == ""
        add_flash(I18n.t("flash.edit.field_required", :field=>"Type"), :error)
      end
      if !@flash_array
        add_sm = StorageManager.new_of_type(@edit[:new][:sm_type])
        set_record_vars(add_sm)
      end

      if !@flash_array && valid_record?(add_sm) && add_sm.save
        AuditEvent.success(build_created_audit(add_sm, @edit))
        session[:edit] = nil  # Clear the edit object from the session object
        render :update do |page|
          page.redirect_to :action=>'show_list', :flash_msg=>I18n.t("flash.add.added",:model=>ui_lookup(:model=>"StorageManager"),:name=>add_sm.name)
        end
      else
        @in_a_form = true
        if !@flash_array
          @edit[:errors].each { |msg| add_flash(msg, :error) }
          add_sm.errors.each do |field,msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
        end
        drop_breadcrumb( {:name=>"Add New Storage Manager", :url=>"/storage_manager/new"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    when "validate"
      # Need to pass in smtype so the proper mixins are loaded.
      if @edit[:new][:sm_type].blank?
        add_flash(I18n.t("flash.edit.field_required", :field=>"Type"), :error)
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
        return
      end
      verify_sm = StorageManager.new_of_type(@edit[:new][:sm_type])
      set_record_vars(verify_sm, :validate)
      @in_a_form = true
      begin
        verify_sm.verify_credentials
      rescue StandardError=>bang
        add_flash("#{bang}", :error)
      else
        add_flash(I18n.t("flash.credentials.validated"))
      end
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  def edit
    assert_privileges("storage_manager_edit")
    @sm = find_by_id_filtered(StorageManager, params[:id])
    set_form_vars
    @in_a_form = true
    session[:changed] = false
    drop_breadcrumb( {:name=>"Edit Storage Manager '#{@sm.name}'", :url=>"/storage_manager/edit/#{@sm.id}"} )
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("sm_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])

    render :update do |page|                    # Use JS to update the display
      if changed != session[:changed]
        session[:changed] = changed
        page << javascript_for_miq_button_visibility(changed)
      end
      if @edit[:default_verify_status] != session[:verify_sm_status]
      session[:verify_sm_status] = @edit[:default_verify_status]
        if @edit[:default_verify_status]
          page << "miqValidateButtons('show', 'default_');"
        else
          page << "miqValidateButtons('hide', 'default_');"
        end
      end
    end
  end

  def update
    assert_privileges("storage_manager_edit")
    return unless load_edit("sm_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      flash = I18n.t("flash.edit.cancelled", :model=>ui_lookup(:model=>"StorageManager"), :name=>@sm.name)
      render :update do |page|
        page.redirect_to :action=>@lastaction, :id=>@sm.id, :display=>session[:sm_display], :flash_msg=>flash
      end
    when "save"
      update_sm = find_by_id_filtered(StorageManager, params[:id])
      set_record_vars(update_sm)
      if valid_record?(update_sm) && update_sm.save
        #update_sm.reload
        AuditEvent.success(build_saved_audit(update_sm, @edit))
        session[:edit] = nil  # clean out the saved info
        render :update do |page|
          page.redirect_to :action=>'show', :id=>@sm.id.to_s, :flash_msg=>I18n.t("flash.edit.saved", :model=>ui_lookup(:model=>"StorageManager"), :name=>update_sm.name)
        end
        return
      else
        @edit[:errors].each { |msg| add_flash(msg, :error) }
        update_sm.errors.each do |field,msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        drop_breadcrumb( {:name=>"Edit Storage Manager '#{@sm.name}'", :url=>"/storage_manager/edit/#{@sm.id}"} )
        @in_a_form = true
        session[:changed] = changed
        @changed = true
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    when "reset"
      params[:edittype] = @edit[:edittype]    # remember the edit type
      add_flash(I18n.t("flash.edit.reset"), :warning)
      @in_a_form = true
      set_verify_status
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      render :update do |page|
        page.redirect_to :action=>'edit', :id=>@sm.id.to_s
      end
    when "validate"
      verify_sm = find_by_id_filtered(StorageManager, params[:id])
      set_record_vars(verify_sm, :validate)
      @in_a_form = true
      @changed = session[:changed]
      begin
        verify_sm.verify_credentials
      rescue StandardError=>bang
        add_flash("#{bang}", :error)
      else
        add_flash(I18n.t("flash.credentials.validated"))
      end
      render :update do |page|
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    session[:sm_summary_cool] = (@settings[:views][:sm_summary_cool] == "summary")
    @summary_view = session[:sm_summary_cool]
    @sm = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@sm)

    @gtl_url = "/storage_manager/show/" << @sm.id.to_s << "?"
    @showtype = "config"
    drop_breadcrumb({:name=>ui_lookup(:tables=>"storage_managers"), :url=>"/storage_manager/show_list?page=#{@current_page}&refresh=y"}, true)

    if ["download_pdf","main","summary_only"].include?(@display)
      #get_tagdata(StorageManager)
      drop_breadcrumb( {:name=>@sm.name + " (Summary)", :url=>"/storage_manager/show/#{@sm.id}"} )
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)
    end
    @lastaction = "show"
    session[:tl_record_id] = @record.id

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  # Show the main MS list view
  def show_list
    process_show_list({:conditions=>["agent_type<>?","VMDB"]})
  end


  private ############################

  # Validate the sm record fields
  def valid_record?(sm)
    valid = true
    @edit[:errors] = Array.new
    if !sm.authentication_password.blank? && sm.authentication_userid.blank?
      @edit[:errors].push("User ID must be entered if Password is entered")
      valid = false
    end
    if @edit[:new][:password] != @edit[:new][:verify]
      @edit[:errors].push("Password and Verify Password fields do not match")
      valid = false
    end
    return valid
  end

  # Set form variables for new Storage Manager
  def set_new_form_vars

    @edit = Hash.new
    @edit[:key] = "sm_edit__new"
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new

    @edit[:new][:name] = nil
    @edit[:sm_types] = StorageManager.storage_manager_types
    @edit[:new][:hostname] = nil
    @edit[:new][:ipaddress] = nil
    @edit[:new][:port] = nil
    @edit[:new][:sm_type] = nil
    #@edit[:new][:agent_type] = nil
    @edit[:new][:zone] = "default"
    @edit[:server_zones] = Array.new
    zones = Zone.all
    zones.each do |zone|
      @edit[:server_zones].push(zone.name)
    end

    @edit[:new][:userid] = nil
    @edit[:new][:password] = nil
    @edit[:new][:verify] = nil

    session[:verify_sm_status] = nil
    set_verify_status

    @edit[:current] = @edit[:new].dup
    session[:edit] = @edit
  end

  # Set form variables for edit
  def set_form_vars

    @edit = Hash.new
    @edit[:sm_id] = @sm.id
    @edit[:key] = "sm_edit__#{@sm.id || "new"}"
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new

    @edit[:new][:name] = @sm.name
    @edit[:sm_types] = StorageManager.storage_manager_types
    @edit[:new][:hostname] = @sm.hostname
    @edit[:new][:ipaddress] = @sm.ipaddress
    @edit[:new][:port] = @sm.port
    @edit[:new][:sm_type] = @sm.type_description
    #@edit[:new][:agent_type] = @sm.agent_type
    if @sm.zone.nil? || @sm.my_zone == ""
      @edit[:new][:zone] = "default"
    else
      @edit[:new][:zone] = @sm.my_zone
    end
    @edit[:server_zones] = Array.new
    zones = Zone.all
    zones.each do |zone|
      @edit[:server_zones].push(zone.name)
    end

    @edit[:new][:userid] = @sm.authentication_userid
    @edit[:new][:password] = @sm.authentication_password
    @edit[:new][:verify] = @sm.authentication_password

    session[:verify_sm_status] = nil
    set_verify_status

    @edit[:current] = @edit[:new].dup
    session[:edit] = @edit
  end

  def set_verify_status
    if @edit[:new][:userid].blank? || @edit[:new][:ipaddress].blank?
      @edit[:default_verify_status] = false
    else
      @edit[:default_verify_status] = (@edit[:new][:password] == @edit[:new][:verify])
    end
  end

  # Get variables from edit form
  def get_form_vars
    @sm = @edit[:sm_id] ? StorageManager.find_by_id(@edit[:sm_id]) : StorageManager.new

    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:hostname] = params[:hostname] if params[:hostname]
    @edit[:new][:ipaddress] = params[:ipaddress] if params[:ipaddress]
    @edit[:new][:port] = params[:port] if params[:port]
    @edit[:new][:sm_type] = params[:sm_type] if params[:sm_type]
    #@edit[:new][:agent_type] = params[:agent_typ] if params[:agent_typ]
    @edit[:new][:zone] = params[:server_zone] if params[:server_zone]

    @edit[:new][:userid] = params[:userid] if params[:userid]
    @edit[:new][:password] = params[:password] if params[:password]
    @edit[:new][:verify] = params[:verify] if params[:verify]

    set_verify_status
  end

  # Set record variables to new values
  def set_record_vars(sm, mode = nil)
    sm.name = @edit[:new][:name]
    sm.hostname = @edit[:new][:hostname]
    sm.ipaddress = @edit[:new][:ipaddress]
    sm.port = @edit[:new][:port]
    #sm.type = @edit[:new][:sm_type]
    #sm.agent_type = @edit[:new][:agent_typ] && @edit[:new][:agent_typ] != "" ? @edit[:new][:agent_typ] : "SMIS"
    sm.zone = Zone.find_by_name(@edit[:new][:zone])

    sm.update_authentication({:default => {:userid=>@edit[:new][:userid], :password=>@edit[:new][:password]}}, {:save => (mode != :validate) })
  end

  # Refresh inventory for selected or single Storage Manager
  def refresh_inventory
    assert_privileges("storage_manager_refresh_inventory")
    sm_button_operation('refresh_inventory', 'Refresh Inventory')
  end

  # Refresh status for selected or single Storage Manager
  def refresh_status_sm
    assert_privileges("storage_manager_refresh_status")
    sm_button_operation('request_status_update', 'Refresh Status')
  end

   # Common Storage Manager button handler routines
  def sm_button_operation(method, display_name)
    sms = Array.new

    # List of Storage Managers
    if @lastaction == "show_list"
      sms = find_checked_items
      if sms.empty?
        add_flash(I18n.t("flash.button.no_records_selected", :model=>ui_lookup(:model=>"StorageManager"), :button=>display_name), :error)
      else
        process_sms(sms, method)
      end

      if @lastaction == "show_list" # In vm controller, refresh show_list, else let the other controller handle it
        show_list
        @refresh_partial = "layouts/gtl"
      end

    else # showing 1 Storage Manager
      if params[:id].nil? || StorageManager.find_by_id(params[:id]).nil?
        add_flash(I18n.t("flash.record.no_longer_exists", :model=>ui_lookup(:model=>"StorageManager")), :error)
        show_list
        @refresh_partial = "layouts/gtl"
      else
        sms.push(params[:id])
        process_sms(sms, method)  unless sms.empty?

        # TODO: tells callers to go back to show_list because this Storage Manager may be gone
        # Should be refactored into calling show_list right here
        if method == 'destroy'
          @single_delete = true unless flash_errors?
        end
      end
    end

    return sms.count
  end

  def process_sms(sms, task)
    if task == "refresh_inventory"
      begin
        StorageManager.refresh_inventory(sms, true)
      rescue StandardError => bang
          add_flash(I18n.t("flash.error_during",
                          :task=>task) << bang.message,
                    :error)
          AuditEvent.failure(:userid=>session[:userid],:event=>"storage_manager_#{task}",
            :message=>"Error during '" << task << "': " << bang.message,
            :target_class=>"StorageManager", :target_id=>id)
       else
        add_flash(I18n.t("flash.record.task_initiated_for_model", :task=>Dictionary::gettext(task, :type=>:task).titleize, :count_model=>pluralize(sms.length,"Storage Manager")))
        AuditEvent.success(:userid=>session[:userid],:event=>"storage_manager_#{task}",
            :message=>"'#{task}' successfully initiated for #{pluralize(sms.length,"Storage Manager")}",
            :target_class=>"StorageManager")
      end
    else
      StorageManager.find_all_by_id(sms, :order => "lower(name)").each do |sm|
        id = sm.id
        sm_name = sm.name
        if task == "destroy"
          audit = {:event=>"sm_record_delete", :message=>"[#{sm_name}] Record deleted", :target_id=>id, :target_class=>"StorageManager", :userid => session[:userid]}
        end
        begin
          sm.send(task.to_sym) if sm.respond_to?(task)    # Run the task
        rescue StandardError => bang
          add_flash(I18n.t("flash.record.error_during_task",
                          :model=>ui_lookup(:model=>"StorageManager"), :name=>sm_name, :task=>task) << bang.message,
                    :error)
          AuditEvent.failure(:userid=>session[:userid],:event=>"storage_manager_#{task}",
            :message=>"#{sm_name}: Error during '" << task << "': " << bang.message,
            :target_class=>"StorageManager", :target_id=>id)
        else
          if task == "destroy"
            AuditEvent.success(audit)
            add_flash(I18n.t("flash.record.deleted", :model=>ui_lookup(:model=>"StorageManager"), :name=>sm_name))
            AuditEvent.success(:userid=>session[:userid],:event=>"storage_manager_#{task}",
              :message=>"#{sm_name}: Delete successful",
              :target_class=>"StorageManager", :target_id=>id)
          else
            add_flash(I18n.t("flash.record.task_started", :model=>ui_lookup(:model=>"StorageManager"), :name=>sm_name, :task=>task))
           AuditEvent.success(:userid=>session[:userid],:event=>"storage_manager_#{task}",
              :message=>"#{sm_name}: '" + task + "' successfully initiated",
              :target_class=>"StorageManager", :target_id=>id)
          end
        end
      end
    end
  end

  # Delete all selected or single displayed sm(s)
  def deletesms
    assert_privileges("storage_manager_delete")
    sm_button_operation('destroy', 'deletion')
  end

  def get_session_data
    @title      = "Storage Managers"
    @layout     = "storage_manager"
    @lastaction = session[:sm_lastaction]
    @display    = session[:sm_display]
    @filters    = session[:sm_filters]
    @catinfo    = session[:sm_catinfo]
  end

  def set_session_data
    session[:sm_lastaction] = @lastaction
    session[:sm_display]    = @display unless @display.nil?
    session[:sm_filters]    = @filters
    session[:sm_catinfo]    = @catinfo
  end

end
