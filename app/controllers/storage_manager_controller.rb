class StorageManagerController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:page] = @current_page unless @current_page.nil?   # Save current page for list refresh
    @refresh_div = "main_div" # Default div for button.rjs to refresh
    redirect_to :action => "new" if params[:pressed] == "storage_manager_new"
    deletesms if params[:pressed] == "storage_manager_delete"
    edit_record if params[:pressed] == "storage_manager_edit"
    refresh_inventory if params[:pressed] == "storage_manager_refresh_inventory"
    refresh_status_sm if params[:pressed] == "storage_manager_refresh_status"

    if !@flash_array && !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    elsif @flash_array && @lastaction == "show"
      @sm = @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if !@flash_array.nil? && params[:pressed] == "storage_manager_delete" && @single_delete
      javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message]  # redirect to build the retire screen
    elsif params[:pressed].ends_with?("_edit")
      if @redirect_controller
        javascript_redirect :controller => @redirect_controller, :action => @refresh_partial, :id => @redirect_id
      else
        javascript_redirect :action => @refresh_partial, :id => @redirect_id
      end
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render :update do |page|
          page << javascript_prologue
          unless @refresh_partial.nil?
            if @refresh_div == "flash_msg_div"
              page.replace(@refresh_div, :partial => @refresh_partial)
            else
              page.replace_html(@refresh_div, :partial => @refresh_partial)
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
    drop_breadcrumb(:name => _("Add New Storage Manager"), :url => "/storage_manager/new")
  end

  def create
    assert_privileges("storage_manager_new")
    return unless load_edit("sm_edit__new")
    get_form_vars
    case params[:button]
    when "cancel"
      javascript_redirect :action => 'show_list', :flash_msg => _("Add of new %{model} was cancelled by the user") %
                          {:model => ui_lookup(:table => "StorageManager")}
    when "add"
      if @edit[:new][:sm_type].nil?
        add_flash(_("Type is required"), :error)
        javascript_flash
        return
      end
      if @edit[:new][:sm_type].nil? || @edit[:new][:sm_type] == ""
        add_flash(_("Type is required"), :error)
      end
      unless @flash_array
        add_sm = StorageManager.new_of_type(@edit[:new][:sm_type])
        set_record_vars(add_sm)
      end

      if !@flash_array && valid_record?(add_sm) && add_sm.save
        AuditEvent.success(build_created_audit(add_sm, @edit))
        session[:edit] = nil  # Clear the edit object from the session object
        javascript_redirect :action => 'show_list', :flash_msg => _("%{model} \"%{name}\" was added") % {:model => ui_lookup(:model => "StorageManager"), :name => add_sm.name}
      else
        @in_a_form = true
        unless @flash_array
          @edit[:errors].each { |msg| add_flash(msg, :error) }
          add_sm.errors.each do |field, msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
        end
        drop_breadcrumb(:name => _("Add New Storage Manager"), :url => "/storage_manager/new")
        javascript_flash
      end
    when "validate"
      # Need to pass in smtype so the proper mixins are loaded.
      if @edit[:new][:sm_type].blank?
        add_flash(_("Type is required"), :error)
        javascript_flash
        return
      end
      verify_sm = StorageManager.new_of_type(@edit[:new][:sm_type])
      set_record_vars(verify_sm, :validate)
      @in_a_form = true
      begin
        verify_sm.verify_credentials
      rescue StandardError => bang
        add_flash("#{bang}", :error)
      else
        add_flash(_("Credential validation was successful"))
      end
      javascript_flash
    end
  end

  def edit
    assert_privileges("storage_manager_edit")
    @sm = find_by_id_filtered(StorageManager, params[:id])
    set_form_vars
    @in_a_form = true
    session[:changed] = false
    drop_breadcrumb(:name => _("Edit Storage Manager '%{name}'") % {:name => @sm.name},
                    :url  => "/storage_manager/edit/#{@sm.id}")
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("sm_edit__#{params[:id]}")
    get_form_vars
    changed = (@edit[:new] != @edit[:current])

    render :update do |page|
      page << javascript_prologue
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
      flash = _("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "StorageManager"), :name => @sm.name}
      javascript_redirect :action => @lastaction, :id => @sm.id, :display => session[:sm_display], :flash_msg => flash
    when "save"
      update_sm = find_by_id_filtered(StorageManager, params[:id])
      set_record_vars(update_sm)
      if valid_record?(update_sm) && update_sm.save
        # update_sm.reload
        AuditEvent.success(build_saved_audit(update_sm, @edit))
        session[:edit] = nil  # clean out the saved info
        javascript_redirect :action => 'show', :id => @sm.id.to_s, :flash_msg => _("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => "StorageManager"), :name => update_sm.name}
        return
      else
        @edit[:errors].each { |msg| add_flash(msg, :error) }
        update_sm.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        drop_breadcrumb(:name => _("Edit Storage Manager '%{name}'") % {:name => @sm.name},
                        :url  => "/storage_manager/edit/#{@sm.id}")
        @in_a_form = true
        session[:changed] = changed
        @changed = true
        javascript_flash
      end
    when "reset"
      params[:edittype] = @edit[:edittype]    # remember the edit type
      add_flash(_("All changes have been reset"), :warning)
      @in_a_form = true
      set_verify_status
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      javascript_redirect :action => 'edit', :id => @sm.id.to_s
    when "validate"
      verify_sm = find_by_id_filtered(StorageManager, params[:id])
      set_record_vars(verify_sm, :validate)
      @in_a_form = true
      @changed = session[:changed]
      begin
        verify_sm.verify_credentials
      rescue StandardError => bang
        add_flash("#{bang}", :error)
      else
        add_flash(_("Credential validation was successful"))
      end
      javascript_flash
    end
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    session[:sm_summary_cool] = (@settings[:views][:sm_summary_cool] == "summary")
    @summary_view = session[:sm_summary_cool]
    @sm = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@sm)

    @gtl_url = "/show"
    @showtype = "config"
    drop_breadcrumb({:name => ui_lookup(:tables => "storage_managers"), :url => "/storage_manager/show_list?page=#{@current_page}&refresh=y"}, true)

    if ["download_pdf", "main", "summary_only"].include?(@display)
      # get_tagdata(StorageManager)
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => @sm.name}, :url => "/storage_manager/show/#{@sm.id}")
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)
    end
    @lastaction = "show"
    session[:tl_record_id] = @record.id

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  # Show the main MS list view
  def show_list
    process_show_list(:conditions => ["agent_type<>?", "VMDB"])
  end

  private ############################

  # Validate the sm record fields
  def valid_record?(sm)
    valid = true
    @edit[:errors] = []
    if !sm.authentication_password.blank? && sm.authentication_userid.blank?
      @edit[:errors].push(_("Username must be entered if Password is entered"))
      valid = false
    end
    if @edit[:new][:password] != @edit[:new][:verify]
      @edit[:errors].push(_("Password and Verify Password fields do not match"))
      valid = false
    end
    valid
  end

  # Set form variables for new Storage Manager
  def set_new_form_vars
    @edit = {}
    @edit[:key] = "sm_edit__new"
    @edit[:new] = {}
    @edit[:current] = {}

    @edit[:new][:name] = nil
    @edit[:sm_types] = StorageManager.storage_manager_types
    @edit[:new][:hostname] = nil
    @edit[:new][:ipaddress] = nil
    @edit[:new][:port] = nil
    @edit[:new][:sm_type] = nil
    # @edit[:new][:agent_type] = nil
    @edit[:new][:zone] = "default"
    @edit[:server_zones] = []
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
    @edit = {}
    @edit[:sm_id] = @sm.id
    @edit[:key] = "sm_edit__#{@sm.id || "new"}"
    @edit[:new] = {}
    @edit[:current] = {}

    @edit[:new][:name] = @sm.name
    @edit[:sm_types] = StorageManager.storage_manager_types
    @edit[:new][:hostname] = @sm.hostname
    @edit[:new][:ipaddress] = @sm.ipaddress
    @edit[:new][:port] = @sm.port
    @edit[:new][:sm_type] = @sm.type_description
    # @edit[:new][:agent_type] = @sm.agent_type
    if @sm.zone.nil? || @sm.my_zone == ""
      @edit[:new][:zone] = "default"
    else
      @edit[:new][:zone] = @sm.my_zone
    end
    @edit[:server_zones] = []
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
    # @edit[:new][:agent_type] = params[:agent_typ] if params[:agent_typ]
    @edit[:new][:zone] = params[:server_zone] if params[:server_zone]

    @edit[:new][:userid] = params[:userid] if params[:userid]
    @edit[:new][:password] = params[:password] if params[:password]
    @edit[:new][:verify] = params[:verify] if params[:verify]
    restore_password if params[:restore_password]
    set_verify_status
  end

  # Set record variables to new values
  def set_record_vars(sm, mode = nil)
    sm.name = @edit[:new][:name]
    sm.hostname = @edit[:new][:hostname]
    sm.ipaddress = @edit[:new][:ipaddress]
    sm.port = @edit[:new][:port]
    # sm.type = @edit[:new][:sm_type]
    # sm.agent_type = @edit[:new][:agent_typ] && @edit[:new][:agent_typ] != "" ? @edit[:new][:agent_typ] : "SMIS"
    sm.zone = Zone.find_by_name(@edit[:new][:zone])

    sm.update_authentication({:default => {:userid => @edit[:new][:userid], :password => @edit[:new][:password]}}, :save => (mode != :validate))
  end

  # Refresh inventory for selected or single Storage Manager
  def refresh_inventory
    assert_privileges("storage_manager_refresh_inventory")
    sm_button_operation('refresh_inventory', _('Refresh Inventory'))
  end

  # Refresh status for selected or single Storage Manager
  def refresh_status_sm
    assert_privileges("storage_manager_refresh_status")
    sm_button_operation('request_status_update', _('Refresh Status'))
  end

  # Common Storage Manager button handler routines
  def sm_button_operation(method, display_name)
    sms = []

    # List of Storage Managers
    if @lastaction == "show_list"
      sms = find_checked_items
      if sms.empty?
        add_flash(_("No %{model} were selected to %{button}") % {:model => ui_lookup(:model => "StorageManager"), :button => display_name}, :error)
      else
        process_sms(sms, method)
      end

      if @lastaction == "show_list" # In vm controller, refresh show_list, else let the other controller handle it
        show_list
        @refresh_partial = "layouts/gtl"
      end

    else # showing 1 Storage Manager
      if params[:id].nil? || StorageManager.find_by_id(params[:id]).nil?
        add_flash(_("%{model} no longer exists") % {:model => ui_lookup(:model => "StorageManager")}, :error)
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

    sms.count
  end

  def process_sms(sms, task)
    if task == "refresh_inventory"
      begin
        StorageManager.refresh_inventory(sms, true)
      rescue StandardError => bang
        add_flash(_("Error during '%{task}': %{message}") % {:task => task, :message => bang.message},
                  :error)
        AuditEvent.failure(:userid => session[:userid], :event => "storage_manager_#{task}",
          :message => _("Error during '%{task} ': %{message}") % {:task => task, :message => bang.message},
          :target_class => "StorageManager", :target_id => id)
      else
        add_flash(n_("%{task} initiated for %{count} Storage Manager from the CFME Database",
                     "%{task} initiated for %{count} Storage Managers from the CFME Database",
                     sms.length) % {:task => task_name(task), :count => sms.length})
        AuditEvent.success(:userid => session[:userid], :event => "storage_manager_#{task}",
            :message => _("'%{task}' successfully initiated for %{items}") %
              {:task => task, :items => pluralize(sms.length, "Storage Manager")},
            :target_class => "StorageManager")
      end
    else
      StorageManager.where(:id => sms).order("lower(name)").each do |sm|
        id = sm.id
        sm_name = sm.name
        if task == "destroy"
          audit = {:event        => "sm_record_delete",
                   :message      => _("[%{name}] Record deleted") % {:name => sm_name},
                   :target_id    => id,
                   :target_class => "StorageManager",
                   :userid       => session[:userid]}
        end
        begin
          sm.send(task.to_sym) if sm.respond_to?(task)    # Run the task
        rescue StandardError => bang
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': %{message}") %
                      {:model   => ui_lookup(:model => "StorageManager"),
                       :name    => sm_name, :task => task,
                       :message => bang.message},
                    :error)
          AuditEvent.failure(:userid => session[:userid], :event => "storage_manager_#{task}",
            :message => _("%{name}: Error during '%{task}': %{message}") % {:name    => sm_name,
                                                                            :task    => task,
                                                                            :message => bang.message},
            :target_class => "StorageManager", :target_id => id)
        else
          if task == "destroy"
            AuditEvent.success(audit)
            add_flash(_("%{model} \"%{name}\": Delete successful") % {:model => ui_lookup(:model => "StorageManager"), :name => sm_name})
            AuditEvent.success(:userid => session[:userid], :event => "storage_manager_#{task}",
              :message => _("%{name}: Delete successful") % {:name => sm_name},
              :target_class => "StorageManager", :target_id => id)
          else
            add_flash(_("%{model} \"%{name}\": %{task} successfully initiated") % {:model => ui_lookup(:model => "StorageManager"), :name => sm_name, :task => task})
            AuditEvent.success(:userid => session[:userid], :event => "storage_manager_#{task}",
               :message => _("%{name}: '%{task}' successfully initiated") % {:name => sm_name, :task => task},
               :target_class => "StorageManager", :target_id => id)
          end
        end
      end
    end
  end

  def restore_password
    if params[:password]
      @edit[:new][:password] = @edit[:new][:verify] = @sm.authentication_password
    end
  end

  # Delete all selected or single displayed sm(s)
  def deletesms
    assert_privileges("storage_manager_delete")
    sm_button_operation('destroy', 'deletion')
  end

  def get_session_data
    @title      = _("Storage Managers")
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
