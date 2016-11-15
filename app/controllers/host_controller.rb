class HostController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin

  def show_association(action, display_name, listicon, method, klass, association = nil, conditions = nil)
    set_config(identify_record(params[:id]))
    super
  end

  def show
    return if perfmenu_click?

    @lastaction = "show"
    @showtype = "config"

    @display = params[:display] || "main" unless control_selected?

    @host = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@host, 'Host')

    @gtl_url = "/show"
    @showtype = "config"
    set_config(@host)
    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@host)
      drop_breadcrumb({:name => _("Hosts"), :url => "/host/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => @host.name }, :url => "/host/show/#{@host.id}")
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)

    when "devices"
      drop_breadcrumb(:name => _("%{name} (Devices)") % {:name => @host.name},
                      :url  => "/host/show/#{@host.id}?display=devices")

    when "os_info"
      drop_breadcrumb(:name => _("%{name} (OS Information)") % {:name => @host.name},
                      :url  => "/host/show/#{@host.id}?display=os_info")

    when "hv_info"
      drop_breadcrumb(:name => _("%{name} (VM Monitor Information)") % {:name => @host.name},
                      :url  => "/host/show/#{@host.id}?display=hv_info")

    when "network"
      drop_breadcrumb(:name => _("%{name} (Network)") % {:name => @host.name},
                      :url  => "/host/show/#{@host.id}?display=network")

      @tree_vms = []
      @network_tree = TreeBuilderNetwork.new(:network_tree, :network, @sb, true, @host, @tree_vms)
      self.x_active_tree = :network_tree

    when "performance"
      @showtype = "performance"
      drop_breadcrumb(:name => _("%{name} Capacity & Utilization") % {:name => @host.name},
                      :url  => "/host/show/#{@host.id}?display=#{@display}&refresh=n")
      perf_gen_init_options               # Intialize perf chart options, charts will be generated async

    when "timeline"
      @showtype = "timeline"
      session[:tl_record_id] = params[:id] if params[:id]
      @record = find_by_id_filtered(Host, session[:tl_record_id])
      @timeline = @timeline_filter = true
      @lastaction = "show_timeline"
      tl_build_timeline                       # Create the timeline report
      drop_breadcrumb(:name => _("Timelines"), :url => "/host/show/#{@record.id}?refresh=n&display=timeline")

    when "compliance_history"
      count = params[:count] ? params[:count].to_i : 10
      @ch_tree = TreeBuilderComplianceHistory.new(:ch_tree, :ch, @sb, true, @host)
      session[:ch_tree] = @ch_tree.tree_nodes

      session[:tree_name] = "ch_tree"
      session[:squash_open] = (count == 1)
      drop_breadcrumb({:name => @host.name, :url => "/host/show/#{@host.id}"}, true)
      if count == 1
        drop_breadcrumb(:name => _("%{name} (Latest Compliance Check)") % {:name => @host.name},
                        :url  => "/host/show/#{@host.id}?display=#{@display}")
      else
        drop_breadcrumb(:name => _("%{name} (Compliance History - Last %{number} Checks)") % {:name => @host.name,:number => count},
                        :url  => "/host/show/#{@host.id}?display=#{@display}")
      end
      @showtype = @display

    when "storage_adapters"
      drop_breadcrumb(:name => _("%{name} (Storage Adapters)") % {:name => @host.name},
                      :url  => "/host/show/#{@host.id}?display=storage_adapters")
      @sa_tree = TreeBuilderStorageAdapters.new(:sa_tree, :sa, @sb, true, @host)
      self.x_active_tree = :sa_tree

    when "miq_templates", "vms"
      title = @display == "vms" ? _("VMs") : _("Templates")
      kls = @display == "vms" ? Vm : MiqTemplate
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @host.name, :title => title},
                      :url  => "/host/show/#{@host.id}?display=#{@display}")
      @view, @pages = get_view(kls, :parent => @host) # Get the records (into a view) and the paginator
      @showtype = @display

    when "cloud_tenants"
      drop_breadcrumb(:name => _("%{name} (All cloud tenants present on this host)") % {:name => @host.name},
                      :url  => "/host/show/#{@host.id}?display=cloud_tenants")
      @view, @pages = get_view(CloudTenant, :parent => @host) # Get the records (into a view) and the paginator
      @showtype = "cloud_tenants"

    when "resource_pools"
      drop_breadcrumb(:name => _("%{name} (All Resource Pools)") % {:name => @host.name},
                      :url  => "/host/show/#{@host.id}?display=resource_pools")
      @view, @pages = get_view(ResourcePool, :parent => @host)  # Get the records (into a view) and the paginator
      @showtype = "resource_pools"

    when "storages"
      drop_breadcrumb(:name => _("%{name} (All %{tables})") % {:name   => @host.name,
                                                               :tables => ui_lookup(:tables => "storages")},
                      :url  => "/host/show/#{@host.id}?display=storages")
      @view, @pages = get_view(Storage, :parent => @host) # Get the records (into a view) and the paginator
      @showtype = "storages"

    when "ontap_logical_disks"
      drop_breadcrumb(:name => _("%{name} (All %{tables})") % {:name   => @host.name,
                                                               :tables => ui_lookup(:tables => "ontap_logical_disk")},
                      :url  => "/host/show/#{@host.id}?display=ontap_logicals_disks")
      @view, @pages = get_view(OntapLogicalDisk, :parent => @host, :parent_method => :logical_disks)  # Get the records (into a view) and the paginator
      @showtype = "ontap_logicals_disks"

    when "ontap_storage_systems"
      drop_breadcrumb(:name => _("%{name} (All %{tables})") % {:name   => @host.name,
                                                               :tables => ui_lookup(:tables => "ontap_storage_system")},
                      :url  => "/host/show/#{@host.id}?display=ontap_storage_systems")
      @view, @pages = get_view(OntapStorageSystem, :parent => @host, :parent_method => :storage_systems)  # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_systems"

    when "ontap_storage_volumes"
      drop_breadcrumb(:name => _("%{name} (All %{tables})") % {:name   => @host.name,
                                                               :tables => ui_lookup(:tables => "ontap_storage_volume")},
                      :url  => "/host/show/#{@host.id}?display=ontap_storage_volumes")
      @view, @pages = get_view(OntapStorageVolume, :parent => @host, :parent_method => :storage_volumes)  # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_volumes"

    when "ontap_file_shares"
      drop_breadcrumb(:name => _("%{name} (All %{tables})") % {:name   => @host.name,
                                                               :tables => ui_lookup(:tables => "ontap_file_share")},
                      :url  => "/host/show/#{@host.id}?display=ontap_file_shares")
      @view, @pages = get_view(OntapFileShare, :parent => @host, :parent_method => :file_shares)  # Get the records (into a view) and the paginator
      @showtype = "ontap_file_shares"
    end
    @lastaction = "show"
    session[:tl_record_id] = @record.id

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def filesystems_subsets
    condition = nil
    label     = _('Files')

    host_service_group = HostServiceGroup.where(:id => params['host_service_group']).first
    if host_service_group
      condition = host_service_group.host_service_group_filesystems_condition
      label     = _("Configuration files of nova service")
    end

    # HACK: UI get_view can't do arel relations, so I need to expose conditions
    condition = condition.to_sql if condition

    return label, condition
  end

  def set_config_local
    set_config(identify_record(params[:id]))
    super
  end
  alias_method :set_config_local, :drift_history
  alias_method :set_config_local, :groups
  alias_method :set_config_local, :patches
  alias_method :set_config_local, :users

  def filesystems
    label, condition = filesystems_subsets
    show_association('filesystems', label, 'filesystems', :filesystems, Filesystem, nil, condition)
  end

  def host_services_subsets
    condition = nil
    label     = _('Services')

    host_service_group = HostServiceGroup.where(:id => params['host_service_group']).first
    if host_service_group
      case params[:status]
      when 'running'
        condition = host_service_group.running_system_services_condition
        label     = _("Running system services of %{name}") % {:name => host_service_group.name}
      when 'failed'
        condition =  host_service_group.failed_system_services_condition
        label     = _("Failed system services of %{name}") % {:name => host_service_group.name}
      when 'all'
        condition = nil
        label     = _("All system services of %{name}") % {:name => host_service_group.name}
      end

      if condition
        # Amend the condition with the openstack host service foreign key
        condition = condition.and(host_service_group.host_service_group_system_services_condition)
      else
        condition = host_service_group.host_service_group_system_services_condition
      end
    end

    # HACK: UI get_view can't do arel relations, so I need to expose conditions
    condition = condition.to_sql if condition

    return label, condition
  end

  def host_services
    label, condition = host_services_subsets
    show_association('host_services', label, 'service', :host_services, SystemService, nil, condition)
  end

  def host_cloud_services
    @center_toolbar = 'host_cloud_services'
    @no_checkboxes = false
    show_association('host_cloud_services', _('Cloud Services'), 'service', :cloud_services, CloudService, nil, nil)
  end

  def advanced_settings
    show_association('advanced_settings', _('Advanced Settings'), 'advancedsetting', :advanced_settings, AdvancedSetting)
  end

  def firewall_rules
    @display = "main"
    show_association('firewall_rules', _('Firewall Rules'), 'firewallrule', :firewall_rules, FirewallRule)
  end

  def guest_applications
    show_association('guest_applications', _('Packages'), 'guest_application', :guest_applications, GuestApplication)
  end

  # Show the main Host list view overriding method from Mixins::GenericListMixin
  def show_list
    session[:host_items] = nil
    process_show_list
  end

  def start
    redirect_to :action => 'show_list'
  end

  def new
    assert_privileges("host_new")
    @host = Host.new
    @in_a_form = true
    drop_breadcrumb(:name => _("Add New Host"), :url => "/host/new")
  end

  def create
    assert_privileges("host_new")
    case params[:button]
    when "cancel"
      javascript_redirect :action    => 'show_list',
                          :flash_msg => _("Add of new %{model} was cancelled by the user") %
                          {:model => ui_lookup(:model => "Host")}
    when "add"
      @host = Host.new
      old_host_attributes = @host.attributes.clone
      set_record_vars(@host, :validate)                        # Set the record variables, but don't save
      @host.vmm_vendor = "unknown"
      if valid_record?(@host) && @host.save
        set_record_vars(@host)                                 # Save the authentication records for this host
        AuditEvent.success(build_saved_audit_hash_angular(old_host_attributes, @host, params[:button] == "add"))
        message = _("%{model} \"%{name}\" was added") % {:model => ui_lookup(:model => "Host"), :name => @host.name}
        javascript_redirect :action    => 'show_list',
                            :flash_msg => message
      else
        @in_a_form = true
        @errors.each { |msg| add_flash(msg, :error) }
        @host.errors.each do |field, msg|
          add_flash("#{field.to_s.capitalize} #{msg}", :error)
        end
        drop_breadcrumb(:name => _("Add New Host"), :url => "/host/new")
        javascript_flash
      end
    when "validate"
      verify_host = Host.new
      set_record_vars(verify_host, :validate)
      @in_a_form = true
      begin
        verify_host.verify_credentials(params[:type])
      rescue => bang
        add_flash(bang.to_s, :error)
      else
        add_flash(_("Credential validation was successful"))
      end
      javascript_flash
    end
  end

  def edit
    assert_privileges("host_edit")
    if session[:host_items].nil?
      @host = find_by_id_filtered(Host, params[:id])
      @in_a_form = true
      session[:changed] = false
      drop_breadcrumb(:name => _("Edit Host '%{name}'") % {:name => @host.name}, :url => "/host/edit/#{@host.id}")
      @title = _("Info/Settings")
    else            # if editing credentials for multi host
      @title = _("Credentials/Settings")
      if params[:selected_host]
        @host = find_by_id_filtered(Host, params[:selected_host])
      else
        @host = Host.new
      end
      @changed = true
      @showlinks = true
      @in_a_form = true
      # Get the db records that are being tagged
      hostitems = Host.find(session[:host_items]).sort { |a, b| a.name <=> b.name }
      @selected_hosts = {}
      hostitems.each do |h|
        @selected_hosts[h.id] = h.name
      end
      build_targets_hash(hostitems)
      @view = get_db_view(Host)       # Instantiate the MIQ Report view object
      @view.table = MiqFilter.records2table(hostitems, @view.cols + ['id'])
    end
  end

  def update
    assert_privileges("host_edit")
    case params[:button]
    when "cancel"
      session[:edit] = nil  # clean out the saved info
      flash = "Edit for Host \""
      @breadcrumbs.pop if @breadcrumbs
      if !session[:host_items].nil?
        flash = _("Edit of credentials for selected %{models} was cancelled by the user") %
          {:models => ui_lookup(:models => "Host")}
        # redirect_to :action => @lastaction, :display=>session[:host_display], :flash_msg=>flash
        javascript_redirect :action => @lastaction, :display => session[:host_display], :flash_msg => flash
      else
        @host = find_by_id_filtered(Host, params[:id])
        flash = _("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model => ui_lookup(:model => "Host"), :name => @host.name}
        javascript_redirect :action => @lastaction, :id => @host.id, :display => session[:host_display], :flash_msg => flash
      end

    when "save"
      if session[:host_items].nil?
        @host = find_by_id_filtered(Host, params[:id])
        old_host_attributes = @host.attributes.clone
        valid_host = find_by_id_filtered(Host, params[:id])
        set_record_vars(valid_host, :validate)                      # Set the record variables, but don't save
        if valid_record?(valid_host) && set_record_vars(@host) && @host.save
          add_flash(_("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => "Host"), :name => @host.name})
          @breadcrumbs.pop if @breadcrumbs
          AuditEvent.success(build_saved_audit_hash_angular(old_host_attributes, @host, false))
          session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
          javascript_redirect :action => "show", :id => @host.id.to_s
          return
        else
          @errors.each { |msg| add_flash(msg, :error) }
          @host.errors.each do |field, msg|
            add_flash("#{field.to_s.capitalize} #{msg}", :error)
          end
          drop_breadcrumb(:name => _("Edit Host '%{name}'") % {:name => @host.name}, :url => "/host/edit/#{@host.id}")
          @in_a_form = true
          javascript_flash
        end
      else
        valid_host = find_by_id_filtered(Host, !params[:validate_id].blank? ?
                                               params[:validate_id] :
                                               session[:host_items].first.to_i)
        # Set the record variables, but don't save
        creds = set_credentials(valid_host, :validate)
        if valid_record?(valid_host)
          @error = Host.batch_update_authentication(session[:host_items], creds)
        end
        if @error || @error.blank?
          # redirect_to :action => 'show_list', :flash_msg=>_("Credentials/Settings saved successfully")
          javascript_redirect :action => 'show_list', :flash_msg => _("Credentials/Settings saved successfully")
        else
          drop_breadcrumb(:name => _("Edit Host '%{name}'") % {:name => @host.name}, :url => "/host/edit/#{@host.id}")
          @in_a_form = true
          # redirect_to :action => 'edit', :flash_msg=>@error, :flash_error =>true
          javascript_flash
        end
      end
    when "reset"
      params[:edittype] = @edit[:edittype]    # remember the edit type
      add_flash(_("All changes have been reset"), :warning)
      @in_a_form = true
      session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
      javascript_redirect :action => 'edit', :id => @host.id.to_s
    when "validate"
      verify_host = find_by_id_filtered(Host, params[:validate_id] ? params[:validate_id].to_i : params[:id])
      if session[:host_items].nil?
        set_record_vars(verify_host, :validate)
      else
        set_credentials(verify_host, :validate)
      end
      @in_a_form = true
      @changed = session[:changed]
      begin
        require 'MiqSshUtil'
        verify_host.verify_credentials(params[:type], :remember_host => params.key?(:remember_host))
      rescue Net::SSH::HostKeyMismatch => e   # Capture the Host key mismatch from the verify
        render :update do |page|
          page << javascript_prologue
          new_url = url_for(:action => "update", :button => "validate", :type => params[:type], :remember_host => "true", :escape => false)
          page << "if (confirm('The Host SSH key has changed, do you want to accept the new key?')) miqAjax('#{new_url}');"
        end
        return
      rescue => bang
        add_flash(bang.to_s, :error)
      else
        add_flash(_("Credential validation was successful"))
      end
      javascript_flash
    end
  end

  def build_saved_audit_hash_angular(old_attributes, new_record, add)
    name  = new_record.respond_to?(:name) ? new_record.name : new_record.description
    msg   = if add
              _("[%{name}] Record added (") % {:name => name}
            else
              _("[%{name}] Record updated (") % {:name => name}
            end
    event = "#{new_record.class.to_s.downcase}_record_#{add ? "add" : "update"}"

    attribute_difference = new_record.attributes.to_a - old_attributes.to_a
    attribute_difference = Hash[*attribute_difference.flatten]

    difference_messages = []

    attribute_difference.each do |key, value|
      difference_messages << _("%{key} changed to %{value}") % {:key => key, :value => value}
    end

    msg = msg + difference_messages.join(", ") + ")"

    {
      :event        => event,
      :target_id    => new_record.id,
      :target_class => new_record.class.base_class.name,
      :userid       => session[:userid],
      :message      => msg
    }
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["vms", "storages"].include?(@display)  # Were we displaying vms/storages

    if params[:pressed].starts_with?("vm_", # Handle buttons from sub-items screen
                                     "miq_template_",
                                     "guest_",
                                     "storage_")

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)

      scanstorage if params[:pressed] == "storage_scan"
      refreshstorage if params[:pressed] == "storage_refresh"
      tag(Storage) if params[:pressed] == "storage_tag"

      # Control transferred to another screen, so return
      return if ["host_drift", "#{pfx}_compare", "#{pfx}_tag", "#{pfx}_policy_sim",
                 "#{pfx}_retire", "#{pfx}_protect", "#{pfx}_ownership",
                 "#{pfx}_reconfigure", "#{pfx}_retire", "#{pfx}_right_size",
                 "storage_tag"].include?(params[:pressed]) && @flash_array.nil?

      unless ["#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone", "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show
      end
    else                                                                        # Handle Host buttons
      params[:page] = @current_page unless @current_page.nil?                     # Save current page for list refresh
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      drift_analysis if params[:pressed] == "common_drift"
      redirect_to :action => "new" if params[:pressed] == "new"
      deletehosts if params[:pressed] == "host_delete"
      comparemiq if params[:pressed] == "host_compare"
      refreshhosts if params[:pressed] == "host_refresh"
      maintenancehosts if params[:pressed] == "host_toggle_maintenance"
      scanhosts if params[:pressed] == "host_scan"
      check_compliance_hosts if params[:pressed] == "host_check_compliance"
      analyze_check_compliance_hosts if params[:pressed] == "host_analyze_check_compliance"
      tag(Host) if params[:pressed] == "host_tag"
      assign_policies(Host) if params[:pressed] == "host_protect"
      edit_record if params[:pressed] == "host_edit"
      custom_buttons if params[:pressed] == "custom_button"
      prov_redirect if params[:pressed] == "host_miq_request_new"
      toggleservicescheduling if params[:pressed] == "host_cloud_service_scheduling_toggle"
      sethoststomanageable if params[:pressed] == "host_manageable"
      introspecthosts if params[:pressed] == "host_introspect"
      providehosts if params[:pressed] == "host_provide"

      # Handle Host power buttons
      if ["host_shutdown", "host_reboot", "host_standby", "host_enter_maint_mode", "host_exit_maint_mode",
          "host_start", "host_stop", "host_reset"].include?(params[:pressed])
        powerbutton_hosts(params[:pressed].split("_")[1..-1].join("_")) # Handle specific power button
      end

      perf_chart_chooser if params[:pressed] == "perf_reload"
      perf_refresh_data if params[:pressed] == "perf_refresh"

      return if ["custom_button"].include?(params[:pressed])    # custom button screen, so return, let custom_buttons method handle everything
      return if ["host_tag", "host_compare", "common_drift",
                 "host_protect", "perf_reload"].include?(params[:pressed]) &&
                @flash_array.nil? # Another screen showing, so return

      if @flash_array.nil? && !@refresh_partial && !["host_miq_request_new"].include?(params[:pressed]) # if no button handler ran, show not implemented msg
        add_flash(_("Button not yet implemented"), :error)
        @refresh_partial = "layouts/flash_msg"
        @refresh_div = "flash_msg_div"
      elsif @flash_array && @lastaction == "show"
        @host = @record = identify_record(params[:id])
        @refresh_partial = "layouts/flash_msg"
        @refresh_div = "flash_msg_div"
      end
    end

    if @lastaction == "show" && ["custom_button", "host_miq_request_new"].include?(params[:pressed])
      @host = @record = identify_record(params[:id])
    end

    if !@flash_array.nil? && params[:pressed] == "host_delete" && @single_delete
      javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message] # redirect to build the retire screen
    elsif params[:pressed].ends_with?("_edit") || ["host_miq_request_new", "#{pfx}_miq_request_new",
                                                   "#{pfx}_clone", "#{pfx}_migrate",
                                                   "#{pfx}_publish"].include?(params[:pressed])
      if @flash_array
        show_list
        replace_gtl_main_div
      else
        if @redirect_controller
          if ["host_miq_request_new", "#{pfx}_clone", "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
            if flash_errors?
              javascript_flash
            else
              javascript_redirect :controller     => @redirect_controller,
                                  :action         => @refresh_partial,
                                  :id             => @redirect_id,
                                  :prov_type      => @prov_type,
                                  :prov_id        => @prov_id,
                                  :org_controller => @org_controller,
                                  :escape         => false
            end
          else
            javascript_redirect :controller => @redirect_controller, :action => @refresh_partial, :id => @redirect_id, :org_controller => @org_controller
          end
        else
          javascript_redirect :action => @refresh_partial, :id => @redirect_id
        end
      end
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  def host_form_fields
    assert_privileges("host_edit")
    host = find_by_id_filtered(Host, params[:id])
    validate_against = session.fetch_path(:edit, :validate_against) &&
                       params[:button] != "reset" ? session.fetch_path(:edit, :validate_against) : nil

    host_hash = {
      :name             => host.name,
      :hostname         => host.hostname,
      :ipmi_address     => host.ipmi_address ? host.ipmi_address : "",
      :custom_1         => host.custom_1 ? host.custom_1 : "",
      :user_assigned_os => host.user_assigned_os,
      :operating_system => !(host.operating_system.nil? || host.operating_system.product_name.nil?),
      :mac_address      => host.mac_address ? host.mac_address : "",
      :default_userid   => host.authentication_userid.to_s,
      :remote_userid    => host.has_authentication_type?(:remote) ? host.authentication_userid(:remote).to_s : "",
      :ws_userid        => host.has_authentication_type?(:ws) ? host.authentication_userid(:ws).to_s : "",
      :ipmi_userid      => host.has_authentication_type?(:ipmi) ? host.authentication_userid(:ipmi).to_s : "",
      :validate_id      => validate_against,
    }

    render :json => host_hash
  end

  private ############################

  def breadcrumb_name(_model)
    title_for_hosts
  end

  # Validate the host record fields
  def valid_record?(host)
    valid = true
    @errors = []
    if !host.authentication_userid.blank? && params[:password] != params[:verify]
      @errors.push(_("Default Password and Verify Password fields do not match"))
      valid = false
      @tabnum = "1"
    end
    if host.authentication_userid.blank? && (!host.authentication_userid(:remote).blank? || !host.authentication_userid(:ws).blank?)
      @errors.push(_("Default User ID must be entered if a Remote Login or Web Services User ID is entered"))
      valid = false
      @tabnum = "1"
    end
    if !host.authentication_userid(:remote).blank? && params[:remote_password] != params[:remote_verify]
      @errors.push(_("Remote Login Password and Verify Password fields do not match"))
      valid = false
      @tabnum ||= "2"
    end
    if !host.authentication_userid(:ws).blank? && params[:ws_password] != params[:ws_verify]
      @errors.push(_("Web Services Password and Verify Password fields do not match"))
      valid = false
      @tabnum ||= "3"
    end
    if !host.authentication_userid(:ipmi).blank? && params[:ipmi_password] != params[:ipmi_verify]
      @errors.push(_("IPMI Password and Verify Password fields do not match"))
      valid = false
      @tabnum ||= "4"
    end
    if params[:ws_port] && !(params[:ws_port] =~ /^\d+$/)
      @errors.push(_("Web Services Listen Port must be numeric"))
      valid = false
    end
    if params[:log_wrapsize] && (!(params[:log_wrapsize] =~ /^\d+$/) || params[:log_wrapsize].to_i == 0)
      @errors.push(_("Log Wrap Size must be numeric and greater than zero"))
      valid = false
    end
    valid
  end

  # Set record variables to new values
  def set_record_vars(host, mode = nil)
    host.name             = params[:name]
    host.hostname         = params[:hostname].strip unless params[:hostname].nil?
    host.ipmi_address     = params[:ipmi_address]
    host.mac_address      = params[:mac_address]
    host.custom_1         = params[:custom_1] unless mode == :validate
    host.user_assigned_os = params[:user_assigned_os]
    set_credentials(host, mode)
    true
  end

  def set_credentials(host, mode)
    creds = {}
    if params[:default_userid]
      default_password = params[:default_password] ? params[:default_password] : host.authentication_password
      creds[:default] = {:userid => params[:default_userid], :password => default_password}
    end
    if params[:remote_userid]
      remote_password = params[:remote_password] ? params[:remote_password] : host.authentication_password(:remote)
      creds[:remote] = {:userid => params[:remote_userid], :password => remote_password}
    end
    if params[:ws_userid]
      ws_password = params[:ws_password] ? params[:ws_password] : host.authentication_password(:ws)
      creds[:ws] = {:userid => params[:ws_userid], :password => ws_password}
    end
    if params[:ipmi_userid]
      ipmi_password = params[:ipmi_password] ? params[:ipmi_password] : host.authentication_password(:ipmi)
      creds[:ipmi] = {:userid => params[:ipmi_userid], :password => ipmi_password}
    end
    host.update_authentication(creds, :save => (mode != :validate))
    creds
  end

  # gather up the host records from the DB
  def get_hosts
    page = params[:page].nil? ? 1 : params[:page].to_i
    @current_page = page

    @items_per_page = @settings[:perpage][@gtl_type.to_sym]   # Get the per page setting for this gtl type
    @host_pages, @hosts = paginate(:hosts, :per_page => @items_per_page, :order => @col_names[get_sort_col] + " " + @sortdir)
  end

  def get_session_data
    @title      = _("Hosts")
    @layout     = "host"
    @drift_db   = "Host"
    @lastaction = session[:host_lastaction]
    @display    = session[:host_display]
    @filters    = session[:host_filters]
    @catinfo    = session[:host_catinfo]
    @base       = session[:vm_compare_base]
  end

  def set_session_data
    session[:host_lastaction] = @lastaction
    session[:host_display]    = @display unless @display.nil?
    session[:host_filters]    = @filters
    session[:host_catinfo]    = @catinfo
    session[:miq_compressed]  = @compressed  unless @compressed.nil?
    session[:miq_exists_mode] = @exists_mode unless @exists_mode.nil?
    session[:vm_compare_base] = @base
  end

  menu_section :inf
end
