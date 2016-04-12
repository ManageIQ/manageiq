module EmsCommon
  extend ActiveSupport::Concern
  include AuthorizationMessagesMixin

  def show
    @display = params[:display] || "main" unless control_selected?

    session[:vm_summary_cool] = (settings(:views, :vm_summary_cool).to_s == "summary")
    @summary_view = session[:vm_summary_cool]
    @ems = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@ems)

    @gtl_url = "/show"
    @showtype = "config"
    drop_breadcrumb({:name => ui_lookup(:tables => @table_name), :url => "/#{@table_name}/show_list?page=#{@current_page}&refresh=y"}, true)

    if ["download_pdf", "main", "summary_only"].include?(@display)
      get_tagdata(@ems)
      drop_breadcrumb(:name => @ems.name + _(" (Summary)"), :url => show_link(@ems))
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)
    elsif @display == "props"
      drop_breadcrumb(:name => @ems.name + _(" (Properties)"), :url => show_link(@ems, :display  =>  "props"))
    elsif @display == "ems_folders"
      if params[:vat]
        drop_breadcrumb(:name => @ems.name + _(" (VMs & Templates)"),
                        :url  => show_link(@ems, :display => "ems_folder", :vat => "true"))
      else
        drop_breadcrumb(:name => @ems.name + _(" (Hosts & Clusters)"),
                        :url  => show_link(@ems, :display => "ems_folders"))
      end
      @showtype = "config"
      build_dc_tree
    elsif @display == "timeline"
      @showtype = "timeline"
      session[:tl_record_id] = params[:id] if params[:id]
      @record = find_by_id_filtered(model, session[:tl_record_id])
      @timeline = @timeline_filter = true
      @lastaction = "show_timeline"
      tl_build_timeline                       # Create the timeline report
      drop_breadcrumb(:name => _("Timelines"), :url => show_link(@record, :refresh => "n", :display => "timeline"))
    elsif @display == "dashboard"
      @showtype = "dashboard"
      @lastaction = "show_dashboard"
      drop_breadcrumb(:name => @ems.name + _(" (Dashboard)"), :url => show_link(@ems))
    elsif @display == "performance"
      @showtype = "performance"
      drop_breadcrumb(:name => _("%{name} Capacity & Utilization") % {:name => @record.name},
                      :url  => "/#{@table_name}/show/#{@record.id}?display=#{@display}&refresh=n")
      perf_gen_init_options               # Initialize perf chart options, charts will be generated async
    elsif ["instances", "images", "miq_templates", "vms"].include?(@display) || session[:display] == "vms" && params[:display].nil?
      if @display == "instances"
        title = _("Instances")
        kls = ManageIQ::Providers::CloudManager::Vm
      elsif @display == "images"
        title = _("Images")
        kls = ManageIQ::Providers::CloudManager::Template
      elsif @display == "miq_templates"
        title = _("Templates")
        kls = MiqTemplate
      elsif @display == "vms"
        title = _("VMs")
        kls = Vm
      end
      view_setup_helper(kls, title, title.singularize)
    elsif (display_class = calculate_display_class(@display, (session[:display] unless params[:display])))
      display_name = display_class.name.underscore.pluralize
      title = ui_lookup(:tables => display_name)
      view_setup_helper(display_class, title, title.singularize)
    elsif @display == "storages" || session[:display] == "storages" && params[:display].nil?
      title = ui_lookup(:tables => "storages")
      view_setup_helper(Storage, _("Managed ") + title, title)
    elsif @display == "ems_clusters"
      view_setup_helper(EmsCluster, title_for_clusters, "Cluster")
    elsif @display == "orchestration_stacks" || session[:display] == "orchestration_stacks" && params[:display].nil?
      title = _("Stacks")
      view_setup_helper(OrchestrationStack, title, title.singularize)
    elsif @display == "persistent_volumes" || session[:display] == "persistent_volumes" && params[:display].nil?
      title = ui_lookup(:tables => "persistent_volumes")
      view_setup_helper(PersistentVolume, title, title.singularize, :persistent_volumes)
    elsif @display == "cloud_object_store_containers" ||
          (session[:display] == "cloud_object_store_containers" && params[:display].nil?)
      title = ui_lookup(:tables => 'cloud_object_stores')
      view_setup_helper(CloudObjectStoreContainer, title, title.singularize)
    else  # Must be Hosts # FIXME !!!
      view_setup_helper(Host, _("Managed Hosts"), _("Host"))
    end
    @lastaction = "show"
    session[:tl_record_id] = @record.id

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def calculate_display_class(display_name, session_display)
    [Container, ContainerReplicator, ContainerNode, ContainerGroup,
     ContainerService, ContainerImage, ContainerRoute, ContainerBuild,
     ContainerProject, ContainerImageRegistry, AvailabilityZone,
     MiddlewareServer, MiddlewareDeployment,
     CloudTenant, CloudVolume, Flavor,
     SecurityGroup, FloatingIp, NetworkRouter, NetworkPort, CloudSubnet, CloudNetwork].detect do |klass|
      name = klass.name.underscore.pluralize
      [display_name, session_display].include?(name)
    end
  end

  def view_setup_helper(kls, title, view_item_name, parent_method = nil)
    drop_breadcrumb(:name => @ems.name + _(" (All %{title})") % {:title => title},
                    :url  => show_link(@ems, :display => @display))
    opts = {:parent => @ems}
    opts[:parent_method] = parent_method if parent_method
    @view, @pages = get_view(kls, **opts)
    @showtype = @display
    notify_about_unauthorized_items(view_item_name, ui_lookup(:tables => @table_name))
  end

  # Show the main MS list view
  def show_list
    process_show_list
  end

  def new
    @doc_url = provider_documentation_url
    assert_privileges("#{permission_prefix}_new")
    @ems = model.new
    set_form_vars
    @in_a_form = true
    session[:changed] = nil
    drop_breadcrumb(:name => _("Add New %{table}") % {:table => ui_lookup(:table => @table_name)},
                    :url  => "/#{@table_name}/new")
  end

  def create
    assert_privileges("#{permission_prefix}_new")
    return unless load_edit("ems_edit__new")
    get_form_vars
    case params[:button]
    when "add"
      if @edit[:new][:emstype].blank?
        add_flash(_("Type is required"), :error)
      end

      if @edit[:new][:emstype] == "scvmm" && @edit[:new][:default_security_protocol] == "kerberos" && @edit[:new][:realm].blank?
        add_flash(_("Realm is required"), :error)
      end

      unless @flash_array
        add_ems = model.model_from_emstype(@edit[:new][:emstype]).new
        set_record_vars(add_ems)
      end
      if !@flash_array && valid_record?(add_ems) && add_ems.save
        AuditEvent.success(build_created_audit(add_ems, @edit))
        session[:edit] = nil  # Clear the edit object from the session object
        render :update do |page|
          page << javascript_prologue
          page.redirect_to :action => 'show_list', :flash_msg => _("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:tables => @table_name), :name => add_ems.name}
        end
      else
        @in_a_form = true
        unless @flash_array
          @edit[:errors].each { |msg| add_flash(msg, :error) }
          add_ems.errors.each do |field, msg|
            add_flash("#{add_ems.class.human_attribute_name(field)} #{msg}", :error)
          end
        end
        drop_breadcrumb(:name => _("Add New %{table}") % {:table => ui_lookup(:table => @table_name)},
                        :url  => "/#{@table_name}/new")
        render :update do |page|
          page << javascript_prologue
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      end
    when "validate"
      verify_ems = model.model_from_emstype(@edit[:new][:emstype]).new
      validate_credentials verify_ems
    end
  end

  def edit
    @doc_url = provider_documentation_url
    assert_privileges("#{permission_prefix}_edit")
    @ems = find_by_id_filtered(model, params[:id])
    set_form_vars
    @in_a_form = true
    session[:changed] = false
    drop_breadcrumb({:name => "Edit #{ui_lookup(:tables => @table_name)} '#{@ems.name}'", :url => "/#{@table_name}/edit/#{@ems.id}"})
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("ems_edit__#{params[:id]}")
    get_form_vars

    changed = edit_changed?
    render :update do |page|
      page << javascript_prologue
      if params[:server_emstype] || params[:default_security_protocol] # Server/protocol type changed
        page.replace_html("form_div", :partial => "shared/views/ems_common/form")
      end
      if params[:server_emstype] # Server type changed
        unless @ems.kind_of?(ManageIQ::Providers::CloudManager)
          # Hide/show C&U credentials tab
          page << "$('#metrics_li').#{params[:server_emstype] == "rhevm" ? "show" : "hide"}();"
        end
        if ["openstack", "openstack_infra"].include?(params[:server_emstype])
          page << "$('#port').val(#{j_str(@edit[:new][:port].to_s)});"
        end
        # Hide/show port field
        page << "$('#port_tr').#{%w(openstack openstack_infra rhevm).include?(params[:server_emstype]) ? "show" : "hide"}();"
      end
      page << javascript_for_miq_button_visibility(changed)
      if @edit[:default_verify_status] != @edit[:saved_default_verify_status]
        @edit[:saved_default_verify_status] = @edit[:default_verify_status]
        page << "miqValidateButtons('#{@edit[:default_verify_status] ? 'show' : 'hide'}', 'default_');"
      end
      if @edit[:metrics_verify_status] != @edit[:saved_metrics_verify_status]
        @edit[:saved_metrics_verify_status] = @edit[:metrics_verify_status]
        page << "miqValidateButtons('#{@edit[:metrics_verify_status] ? 'show' : 'hide'}', 'metrics_');"
      end
      if @edit[:amqp_verify_status] != @edit[:saved_amqp_verify_status]
        @edit[:saved_amqp_verify_status] = @edit[:amqp_verify_status]
        page << "miqValidateButtons('#{@edit[:amqp_verify_status] ? 'show' : 'hide'}', 'amqp_');"
      end
      if @edit[:bearer_verify_status] != @edit[:saved_bearer_verify_status]
        @edit[:saved_bearer_verify_status] = @edit[:bearer_verify_status]
        page << "miqValidateButtons('#{@edit[:bearer_verify_status] ? 'show' : 'hide'}', 'bearer_');"
      end
    end
  end

  def update
    assert_privileges("#{permission_prefix}_edit")
    return unless load_edit("ems_edit__#{params[:id]}")
    get_form_vars
    case params[:button]
    when "cancel"   then update_button_cancel
    when "save"     then update_button_save
    when "reset"    then update_button_reset
    when "validate" then
      @changed = session[:changed]
      update_button_validate
    end
  end

  def update_button_cancel
    session[:edit] = nil  # clean out the saved info
    _model = model
    render :update do |page|
      page << javascript_prologue
      page.redirect_to(:action => @lastaction, :id => @ems.id, :display => session[:ems_display],
                       :flash_msg => _("Edit of %{model} \"%{name}\" was cancelled by the user") %
                       {:model => ui_lookup(:model => _model.to_s), :name => @ems.name})
    end
  end
  private :update_button_cancel

  def edit_changed?
    @edit[:new] != @edit[:current]
  end

  def update_button_save
    changed = edit_changed?
    update_ems = find_by_id_filtered(model, params[:id])
    set_record_vars(update_ems)
    if valid_record?(update_ems) && update_ems.save
      update_ems.reload
      flash = _("%{model} \"%{name}\" was saved") %
              {:model => ui_lookup(:model => model.to_s), :name => update_ems.name}
      AuditEvent.success(build_saved_audit(update_ems, @edit))
      session[:edit] = nil  # clean out the saved info
      render :update do |page|
        page << javascript_prologue
        page.redirect_to :action => 'show', :id => @ems.id.to_s, :flash_msg => flash
      end
      return
    else
      @edit[:errors].each { |msg| add_flash(msg, :error) }
      update_ems.errors.each do |field, msg|
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
      end
      drop_breadcrumb(:name => _("Edit %{table} '%{name}'") % {:table => ui_lookup(:table => @table_name),
                                                               :name  => @ems.name},
                      :url  => "/#{@table_name}/edit/#{@ems.id}")
      @in_a_form = true
      session[:changed] = changed
      @changed = true
      render_flash
    end
  end
  private :update_button_save

  def update_button_reset
    params[:edittype] = @edit[:edittype]    # remember the edit type
    add_flash(_("All changes have been reset"), :warning)
    @in_a_form = true
    set_verify_status
    session[:flash_msgs] = @flash_array.dup                 # Put msgs in session for next transaction
    render :update do |page|
      page << javascript_prologue
      page.redirect_to :action => 'edit', :id => @ems.id.to_s
    end
  end
  private :update_button_reset

  def update_button_validate
    verify_ems = find_by_id_filtered(model, params[:id])
    validate_credentials verify_ems
  end
  private :update_button_validate

  def validate_credentials(verify_ems)
    set_record_vars(verify_ems, :validate)
    @in_a_form = true
    @changed = session[:changed]

    # validate button should say "revalidate" if the form is unchanged
    revalidating = !edit_changed?
    result, details = verify_ems.authentication_check(params[:type], :save => revalidating)
    if result
      add_flash(_("Credential validation was successful"))
    else
      add_flash(_("Credential validation was not successful: %{details}") % {:details => details}, :error)
    end

    render_flash
  end
  private :validate_credentials

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["vms", "hosts", "storages", "instances", "images"].include?(@display)  # Were we displaying vms/hosts/storages
    params[:page] = @current_page unless @current_page.nil?   # Save current page for list refresh

    if params[:pressed].starts_with?("vm_", # Handle buttons from sub-items screen
                                     "miq_template_",
                                     "guest_",
                                     "image_",
                                     "instance_",
                                     "storage_",
                                     "ems_cluster_",
                                     "host_")

      scanhosts if params[:pressed] == "host_scan"
      analyze_check_compliance_hosts if params[:pressed] == "host_analyze_check_compliance"
      check_compliance_hosts if params[:pressed] == "host_check_compliance"
      refreshhosts if params[:pressed] == "host_refresh"
      tag(Host) if params[:pressed] == "host_tag"
      assign_policies(Host) if params[:pressed] == "host_protect"
      deletehosts if params[:pressed] == "host_delete"
      comparemiq if params[:pressed] == "host_compare"
      edit_record  if params[:pressed] == "host_edit"

      scanclusters if params[:pressed] == "ems_cluster_scan"
      tag(EmsCluster) if params[:pressed] == "ems_cluster_tag"
      assign_policies(EmsCluster) if params[:pressed] == "ems_cluster_protect"
      deleteclusters if params[:pressed] == "ems_cluster_delete"
      comparemiq if params[:pressed] == "ems_cluster_compare"

      scanstorage if params[:pressed] == "storage_scan"
      refreshstorage if params[:pressed] == "storage_refresh"
      tag(Storage) if params[:pressed] == "storage_tag"
      deletestorages if params[:pressed] == "storage_delete"

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      # Handle Host power buttons
      if ["host_shutdown", "host_reboot", "host_standby", "host_enter_maint_mode", "host_exit_maint_mode",
          "host_start", "host_stop", "host_reset"].include?(params[:pressed])
        powerbutton_hosts(params[:pressed].split("_")[1..-1].join("_")) # Handle specific power button
      else
        process_vm_buttons(pfx)
        # Control transferred to another screen, so return
        return if ["host_tag", "#{pfx}_policy_sim", "host_scan", "host_refresh", "host_protect",
                   "host_compare", "#{pfx}_compare", "#{pfx}_tag", "#{pfx}_retire",
                   "#{pfx}_protect", "#{pfx}_ownership", "#{pfx}_refresh", "#{pfx}_right_size",
                   "#{pfx}_reconfigure", "storage_tag", "ems_cluster_compare",
                   "ems_cluster_protect", "ems_cluster_tag"].include?(params[:pressed]) &&
                  @flash_array.nil?

        unless ["host_edit", "#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone",
                "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
          @refresh_div = "main_div"
          @refresh_partial = "layouts/gtl"
          show                                                        # Handle EMS buttons
        end
      end
    else
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      redirect_to :action => "new" if params[:pressed] == "new"
      deleteemss if params[:pressed] == "#{@table_name}_delete"
      refreshemss if params[:pressed] == "#{@table_name}_refresh"
      #     scanemss if params[:pressed] == "scan"
      tag(model) if params[:pressed] == "#{@table_name}_tag"
      assign_policies(model) if params[:pressed] == "#{@table_name}_protect"
      edit_record if params[:pressed] == "#{@table_name}_edit"
      if params[:pressed] == "ems_cloud_timeline"
        @showtype = "timeline"
        @record = find_by_id_filtered(model, params[:id])
        @timeline = @timeline_filter = true
        @lastaction = "show_timeline"
        tl_build_timeline                       # Create the timeline report
        drop_breadcrumb(:name => _("Timelines"), :url => show_link(@record, :refresh => "n", :display => "timeline"))
        session[:tl_record_id] = @record.id
        render :update do |page|
          page << javascript_prologue
          page.redirect_to  polymorphic_path(@record, :display => 'timeline')
        end
        return
      end
      if params[:pressed] == "refresh_server_summary"
        render :update do |page|
          page << javascript_prologue
          page.redirect_to  :back
        end
        return
      end

      custom_buttons if params[:pressed] == "custom_button"

      return if ["custom_button"].include?(params[:pressed])    # custom button screen, so return, let custom_buttons method handle everything
      return if ["#{@table_name}_tag", "#{@table_name}_protect", "#{@table_name}_timeline"].include?(params[:pressed]) &&
                @flash_array.nil? # Tag screen showing, so return
      check_if_button_is_implemented
    end

    if !@flash_array.nil? && params[:pressed] == "#{@table_name}_delete" && @single_delete
      render :update do |page|
        page << javascript_prologue
        page.redirect_to :action => 'show_list', :flash_msg => @flash_array[0][:message]  # redirect to build the retire screen
      end
    elsif params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new", "#{pfx}_clone",
                                                   "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      render_or_redirect_partial(pfx)
    else
      if @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  def provider_documentation_url
    "http://manageiq.org/documentation/getting-started/#adding-a-provider"
  end

  private ############################

  def set_verify_status
    edit_new = @edit[:new]
    if edit_new[:emstype] == "ec2"
      if edit_new[:default_userid].blank? || edit_new[:provider_region].blank?
        @edit[:default_verify_status] = false
      else
        @edit[:default_verify_status] = (edit_new[:default_password] == edit_new[:default_verify])
      end
    else
      if edit_new[:default_userid].blank? || edit_new[:hostname].blank? || edit_new[:emstype].blank?
        @edit[:default_verify_status] = false
      else
        @edit[:default_verify_status] = (edit_new[:default_password] == edit_new[:default_verify])
      end
    end

    if edit_new[:metrics_userid].blank? || edit_new[:hostname].blank? || edit_new[:emstype].blank?
      @edit[:metrics_verify_status] = false
    else
      @edit[:metrics_verify_status] = (edit_new[:metrics_password] == edit_new[:metrics_verify])
    end

    if edit_new[:bearer_token].blank? || edit_new[:hostname].blank? || edit_new[:emstype].blank?
      @edit[:bearer_verify_status] = false
    else
      @edit[:bearer_verify_status] = true
    end

    # check if any of amqp_userid, amqp_password, amqp_verify, :hostname, :emstype are blank
    if any_blank_fields?(edit_new, [:amqp_userid, :amqp_password, :amqp_verify, :hostname, :emstype])
      @edit[:amqp_verify_status] = false
    else
      @edit[:amqp_verify_status] = (edit_new[:amqp_password] == edit_new[:amqp_verify])
    end
  end

  # Build the tree object to display the ems datacenter info
  def build_dc_tree
    # Build the datacenter JSON object
    @sb[:vat] = false if params[:action] != "treesize"        # need to set this, to remember vat, treesize doesnt pass in param[:vat]
    vat = params[:vat] ? true : (@sb[:vat] ? true : false)    # use @sb[:vat] when coming from treesize
    @sb[:tree_hosts_hash] = {} # Capture all Host ids in the tree
    @sb[:tree_vms_hash]   = {} # Capture all VM ids in the tree
    # do not want to store ems object in session hash,
    # need to get record incase coming from treesize to rebuild refreshed tree
    @sb[:ems_id] = @ems.id if @ems
    @ems = model.find(@sb[:ems_id]) unless @ems
    # Build the ems node
    ems_node = TreeNodeBuilder.generic_tree_node(
      "ems-#{to_cid(@ems.id)}",
      @ems.name,
      "vendor-#{@ems.image_name}.png",
      "#{ui_lookup(:table => @table_name)}: #{@ems.name}",
      :cfme_no_click => true,
      :expand        => true,
      :style_class   => "cfme-no-cursor-node"
    )
    ems_kids = []
    @sb[:open_tree_nodes] = [] if params[:action] != "treesize"
    @ems.children.each do |c|
      ems_kids += get_dc_node(c, ems_node[:key], vat)  # Add child node(s) to tree
    end
    ems_node[:children] = ems_kids unless ems_kids.empty?

    session[:dc_tree] = [ems_node].to_json
    session[:tree] = "dc"
    if vat
      session[:tree_name] = "vt_tree"
    else
      session[:tree_name] = "dc_tree"
    end
    build_vm_host_array if %w(show treesize).include?(params[:action])
  end

  # Add the children of a node that is being expanded (autoloaded)
  def tree_add_child_nodes(id)
    get_dc_child_nodes(id)
  end

  # Validate the ems record fields
  def valid_record?(ems)
    @edit[:errors] = []
    if ems.emstype == "scvmm" && ems.security_protocol == "kerberos" && ems.realm.blank?
      add_flash(_("Realm is required"), :error)
    end
    if !ems.authentication_password.blank? && ems.authentication_userid.blank?
      @edit[:errors].push(_("Username must be entered if Password is entered"))
    end
    if @edit[:new][:password] != @edit[:new][:verify]
      @edit[:errors].push(_("Password/Verify Password do not match"))
    end
    if ems.supports_authentication?(:metrics) && @edit[:new][:metrics_password] != @edit[:new][:metrics_verify]
      @edit[:errors].push(_("C & U Database Login Password and Verify Password fields do not match"))
    end
    if ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
      unless @edit[:new][:host_default_vnc_port_start] =~ /^\d+$/ || @edit[:new][:host_default_vnc_port_start].blank?
        @edit[:errors].push(_("Default Host VNC Port Range Start must be numeric"))
      end
      unless @edit[:new][:host_default_vnc_port_end] =~ /^\d+$/ || @edit[:new][:host_default_vnc_port_end].blank?
        @edit[:errors].push(_("Default Host VNC Port Range End must be numeric"))
      end
      unless (@edit[:new][:host_default_vnc_port_start].blank? &&
          @edit[:new][:host_default_vnc_port_end].blank?) ||
             (!@edit[:new][:host_default_vnc_port_start].blank? &&
                 !@edit[:new][:host_default_vnc_port_end].blank?)
        @edit[:errors].push(_("To configure the Host Default VNC Port Range, both start and end ports are required"))
      end
      if !@edit[:new][:host_default_vnc_port_start].blank? &&
         !@edit[:new][:host_default_vnc_port_end].blank?
        if @edit[:new][:host_default_vnc_port_end].to_i < @edit[:new][:host_default_vnc_port_start].to_i
          @edit[:errors].push(_("The Host Default VNC Port Range ending port must be equal to or higher than the starting point"))
        end
      end
    end
    @edit[:errors].empty?
  end

  # Set form variables for edit
  def set_form_vars
    form_instance_vars

    @edit = {}
    @edit[:ems_id] = @ems.id
    @edit[:key] = "ems_edit__#{@ems.id || "new"}"
    @edit[:new] = {}
    @edit[:current] = {}

    @edit[:new][:name] = @ems.name
    @edit[:new][:provider_region] = @ems.provider_region
    @edit[:new][:hostname] = @ems.hostname
    @edit[:new][:emstype] = @ems.emstype
    @edit[:amazon_regions] = get_regions('Amazon') if @ems.kind_of?(ManageIQ::Providers::Amazon::CloudManager)
    @edit[:google_regions] = get_regions('Google') if @ems.kind_of?(ManageIQ::Providers::Google::CloudManager)
    @edit[:new][:port] = @ems.port
    @edit[:new][:api_version] = @ems.api_version
    @edit[:new][:provider_id] = @ems.provider_id

    if @ems.kind_of?(ManageIQ::Providers::Openstack::CloudManager) ||
       @ems.kind_of?(ManageIQ::Providers::Openstack::InfraManager)
      # Special behaviour for OpenStack while keeping it backwards compatible for the rest
      @edit[:protocols] = retrieve_openstack_security_protocols
    else
      @edit[:protocols] = [['Basic (SSL)', 'ssl'], ['Kerberos', 'kerberos']]
    end

    if @ems.kind_of?(ManageIQ::Providers::Openstack::CloudManager) ||
       @ems.kind_of?(ManageIQ::Providers::Openstack::InfraManager)
      # Special behaviour for OpenStack while keeping it backwards compatible for the rest
      @edit[:new][:default_security_protocol] = @ems.security_protocol ? @ems.security_protocol : 'ssl'
    else
      if @ems.id
        # for existing provider before this fix, set default to ssl
        @edit[:new][:default_security_protocol] = @ems.security_protocol ? @ems.security_protocol : 'ssl'
      else
        @edit[:new][:default_security_protocol] = 'kerberos'
      end
    end

    @edit[:new][:realm] = @ems.realm if @edit[:new][:emstype] == "scvmm"
    if @ems.zone.nil? || @ems.my_zone == ""
      @edit[:new][:zone] = "default"
    else
      @edit[:new][:zone] = @ems.my_zone
    end

    @edit[:server_zones] = Zone.order('lower(description)').collect { |z| [z.description, z.name] }

    @edit[:openstack_infra_providers] = ManageIQ::Providers::Openstack::Provider.order('lower(name)').each_with_object([["---", nil]]) do |openstack_infra_provider, x|
      x.push([openstack_infra_provider.name, openstack_infra_provider.id])
    end

    @edit[:openstack_api_versions] = retrieve_openstack_api_versions

    @edit[:new][:default_userid] = @ems.authentication_userid
    @edit[:new][:default_password] = @ems.authentication_password
    @edit[:new][:default_verify] = @ems.authentication_password

    @edit[:new][:metrics_userid] = @ems.has_authentication_type?(:metrics) ? @ems.authentication_userid(:metrics).to_s : ""
    @edit[:new][:metrics_password] = @ems.has_authentication_type?(:metrics) ? @ems.authentication_password(:metrics).to_s : ""
    @edit[:new][:metrics_verify] = @ems.has_authentication_type?(:metrics) ? @ems.authentication_password(:metrics).to_s : ""

    @edit[:new][:amqp_userid] = @ems.has_authentication_type?(:amqp) ? @ems.authentication_userid(:amqp).to_s : ""
    @edit[:new][:amqp_password] = @ems.has_authentication_type?(:amqp) ? @ems.authentication_password(:amqp).to_s : ""
    @edit[:new][:amqp_verify] = @ems.has_authentication_type?(:amqp) ? @ems.authentication_password(:amqp).to_s : ""

    @edit[:new][:ssh_keypair_userid] = @ems.has_authentication_type?(:ssh_keypair) ? @ems.authentication_userid(:ssh_keypair).to_s : ""
    @edit[:new][:ssh_keypair_password] = @ems.has_authentication_type?(:ssh_keypair) ? @ems.authentication_key(:ssh_keypair).to_s : ""

    @edit[:new][:bearer_token] = @ems.has_authentication_type?(:bearer) ? @ems.authentication_token(:bearer).to_s : ""
    @edit[:new][:bearer_verify] = @ems.has_authentication_type?(:bearer) ? @ems.authentication_token(:bearer).to_s : ""

    if @ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
      @edit[:new][:host_default_vnc_port_start] = @ems.host_default_vnc_port_start.to_s
      @edit[:new][:host_default_vnc_port_end] = @ems.host_default_vnc_port_end.to_s
    end
    @edit[:ems_types] = model.supported_types_and_descriptions_hash
    @edit[:saved_default_verify_status] = nil
    @edit[:saved_metrics_verify_status] = nil
    @edit[:saved_bearer_verify_status] = nil
    @edit[:saved_amqp_verify_status] = nil
    set_verify_status

    @edit[:current] = @edit[:new].dup
    session[:edit] = @edit
  end

  def form_instance_vars
    @server_zones = []
    zones = Zone.order('lower(description)')
    zones.each do |zone|
      @server_zones.push([zone.description, zone.name])
    end
    @ems_types = Array(model.supported_types_and_descriptions_hash.invert).sort_by(&:first)
    @amazon_regions, @azure_regions, @google_regions = %w(Amazon Azure Google).map do |provider_name|
      get_regions(provider_name)
    end
    @openstack_infra_providers = retrieve_openstack_infra_providers
    @openstack_security_protocols = retrieve_openstack_security_protocols
    @scvmm_security_protocols = [['Basic (SSL)', 'ssl'], ['Kerberos', 'kerberos']]
    @openstack_api_versions = retrieve_openstack_api_versions
    @emstype_display = model.supported_types_and_descriptions_hash[@ems.emstype]
  end

  def get_regions(provider_name)
    regions = {}
    "ManageIQ::Providers::#{provider_name}::Regions".constantize.all.each do |region|
      regions[region[:name]] = region[:description]
    end
    regions
  end

  def retrieve_openstack_infra_providers
    ManageIQ::Providers::Openstack::Provider.pluck(:name, :id)
  end

  def retrieve_openstack_api_versions
    [['Keystone v2', 'v2'], ['Keystone v3', 'v3']]
  end

  def retrieve_openstack_security_protocols
    [['SSL without validation', 'ssl'], ['SSL', 'ssl-with-validation'], ['Non-SSL', 'non-ssl']]
  end

  # Get variables from edit form
  def get_form_vars
    @ems = @edit[:ems_id] ? model.find_by_id(@edit[:ems_id]) : model.new

    @edit[:new][:name] = params[:name] if params[:name]
    @edit[:new][:ipaddress] = @edit[:new][:hostname] = "" if params[:server_emstype]
    @edit[:new][:provider_region] = params[:provider_region] if params[:provider_region]
    @edit[:new][:hostname] = params[:hostname] if params[:hostname]
    if params[:server_emstype]
      @edit[:new][:provider_region] = @ems.provider_region
      @edit[:new][:emstype] = params[:server_emstype]
      if ["openstack", "openstack_infra"].include?(params[:server_emstype])
        @edit[:new][:port] = @ems.port ? @ems.port : 5000
        @edit[:new][:api_version] = @ems.api_version ? @ems.api_version : 'v2'
        @edit[:new][:default_security_protocol] = @ems.security_protocol ? @ems.security_protocol : 'ssl'
      elsif params[:server_emstype] == ManageIQ::Providers::Kubernetes::ContainerManager.ems_type
        @edit[:new][:port] = @ems.port ? @ems.port : ManageIQ::Providers::Kubernetes::ContainerManager::DEFAULT_PORT
      elsif params[:server_emstype] == ManageIQ::Providers::Openshift::ContainerManager.ems_type
        @edit[:new][:port] = @ems.port ? @ems.port : ManageIQ::Providers::Openshift::ContainerManager::DEFAULT_PORT
      elsif params[:server_emstype] == ManageIQ::Providers::Atomic::ContainerManager.ems_type
        @edit[:new][:port] = @ems.port ? @ems.port : ManageIQ::Providers::Atomic::ContainerManager::DEFAULT_PORT
      elsif params[:server_emstype] == ManageIQ::Providers::OpenshiftEnterprise::ContainerManager.ems_type
        @edit[:new][:port] = @ems.port ? @ems.port : ManageIQ::Providers::OpenshiftEnterprise::ContainerManager::DEFAULT_PORT
      elsif params[:server_emstype] == ManageIQ::Providers::AtomicEnterprise::ContainerManager.ems_type
        @edit[:new][:port] = @ems.port ? @ems.port : ManageIQ::Providers::AtomicEnterprise::ContainerManager::DEFAULT_PORT
      else
        @edit[:new][:port] = nil
      end

      if ["openstack", "openstack_infra"].include?(params[:server_emstype])
        @edit[:protocols] = retrieve_openstack_security_protocols
      else
        @edit[:protocols] = [[_('Basic (SSL)'), 'ssl'], ['Kerberos', 'kerberos']]
      end
    end
    @edit[:new][:port] = params[:port] if params[:port]
    @edit[:new][:api_version] = params[:api_version] if params[:api_version]
    @edit[:new][:provider_id] = params[:provider_id] if params[:provider_id]
    @edit[:new][:zone] = params[:server_zone] if params[:server_zone]

    @edit[:new][:default_userid] = params[:default_userid] if params[:default_userid]
    @edit[:new][:default_password] = params[:default_password] if params[:default_password]
    @edit[:new][:default_verify] = params[:default_verify] if params[:default_verify]

    @edit[:new][:metrics_userid] = params[:metrics_userid] if params[:metrics_userid]
    @edit[:new][:metrics_password] = params[:metrics_password] if params[:metrics_password]
    @edit[:new][:metrics_verify] = params[:metrics_verify] if params[:metrics_verify]

    @edit[:new][:amqp_userid] = params[:amqp_userid] if params[:amqp_userid]
    @edit[:new][:amqp_password] = params[:amqp_password] if params[:amqp_password]
    @edit[:new][:amqp_verify] = params[:amqp_verify] if params[:amqp_verify]

    @edit[:new][:ssh_keypair_userid] = params[:ssh_keypair_userid] if params[:ssh_keypair_userid]
    @edit[:new][:ssh_keypair_password] = params[:ssh_keypair_password] if params[:ssh_keypair_password]

    @edit[:new][:bearer_token] = params[:bearer_token] if params[:bearer_token]
    @edit[:new][:bearer_verify] = params[:bearer_verify] if params[:bearer_verify]

    @edit[:new][:host_default_vnc_port_start] = params[:host_default_vnc_port_start] if params[:host_default_vnc_port_start]
    @edit[:new][:host_default_vnc_port_end] = params[:host_default_vnc_port_end] if params[:host_default_vnc_port_end]
    @edit[:amazon_regions] = get_regions('Amazon') if @edit[:new][:emstype] == "ec2"
    @edit[:google_regions] = get_regions('Google') if @edit[:new][:emstype] == "gce"
    @edit[:new][:default_security_protocol] = params[:default_security_protocol] if params[:default_security_protocol]
    # TODO: (julian) Silly hack until we move Infra over to Angular to be consistant with Cloud
    @edit[:new][:default_security_protocol] = params[:security_protocol] if params[:security_protocol]
    @edit[:new][:amqp_security_protocol] = params[:amqp_security_protocol] if params[:amqp_security_protocol]
    @edit[:new][:realm] = nil if params[:default_security_protocol]
    @edit[:new][:realm] = params[:realm] if params[:realm]
    restore_password if params[:restore_password]
    set_verify_status
  end

  # Set record variables to new values
  def set_record_vars(ems, mode = nil)
    ems.name = @edit[:new][:name]
    ems.provider_region = @edit[:new][:provider_region]
    ems.hostname = @edit[:new][:hostname].strip unless @edit[:new][:hostname].nil?
    ems.port = @edit[:new][:port] if ems.supports_port?
    ems.api_version = @edit[:new][:api_version] if ems.supports_api_version?
    ems.security_protocol = @edit[:new][:default_security_protocol] if ems.supports_security_protocol?
    ems.provider_id = @edit[:new][:provider_id] if ems.supports_provider_id?
    ems.zone = Zone.find_by_name(@edit[:new][:zone])

    if ems.kind_of?(ManageIQ::Providers::Microsoft::InfraManager)
      # TODO should be refactored to support methods, although there seems to be no UI for Microsoft provider
      # TODO: (julian) Silly hack until we move Infra over to Angular to be consistant with Cloud
      ems.security_protocol = @edit[:new][:default_security_protocol]
      ems.realm = @edit[:new][:realm]
    end

    if ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
      ems.host_default_vnc_port_start = @edit[:new][:host_default_vnc_port_start].blank? ? nil : @edit[:new][:host_default_vnc_port_start].to_i
      ems.host_default_vnc_port_end = @edit[:new][:host_default_vnc_port_end].blank? ? nil : @edit[:new][:host_default_vnc_port_end].to_i
    end

    creds = {}
    creds[:default] = {:userid => @edit[:new][:default_userid], :password => @edit[:new][:default_password]} unless @edit[:new][:default_userid].blank?
    if ems.supports_authentication?(:metrics) && !@edit[:new][:metrics_userid].blank?
      creds[:metrics] = {:userid => @edit[:new][:metrics_userid], :password => @edit[:new][:metrics_password]}
    end
    if ems.supports_authentication?(:amqp) && !@edit[:new][:amqp_userid].blank?
      creds[:amqp] = {:userid => @edit[:new][:amqp_userid], :password => @edit[:new][:amqp_password]}
    end
    if ems.supports_authentication?(:ssh_keypair) && !@edit[:new][:ssh_keypair_userid].blank?
      creds[:ssh_keypair] = {:userid => @edit[:new][:ssh_keypair_userid], :auth_key => @edit[:new][:ssh_keypair_password]}
    end
    if ems.supports_authentication?(:bearer) && !@edit[:new][:bearer_token].blank?
      creds[:bearer] = {:auth_key => @edit[:new][:bearer_token]}
    end
    if ems.supports_authentication?(:auth_key) && !@edit[:new][:service_account].blank?
      creds[:default] = {:auth_key => @edit[:new][:service_account], :userid => "_"}
    end
    ems.update_authentication(creds, :save => (mode != :validate))
  end

  def process_emss(emss, task)
    emss, emss_out_region = filter_ids_in_region(emss, "Provider")
    return if emss.empty?

    if task == "refresh_ems"
      model.refresh_ems(emss, true)
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % \
        {:task        => task_name(task).gsub("Ems", "#{ui_lookup(:tables => @table_name)}"),
         :count_model => pluralize(emss.length, ui_lookup(:table => @table_name))})
      AuditEvent.success(:userid => session[:userid], :event => "#{@table_name}_#{task}",
          :message => _("'%{task}' successfully initiated for %{table}") %
            {:task => task, :table => pluralize(emss.length, "#{ui_lookup(:tables => @table_name)}")},
          :target_class => model.to_s)
    elsif task == "destroy"
      model.where(:id => emss).order("lower(name)").each do |ems|
        id = ems.id
        ems_name = ems.name
        audit = {:event        => "ems_record_delete_initiated",
                 :message      => _("[%{name}] Record delete initiated") % {:name => ems_name},
                 :target_id    => id,
                 :target_class => model.to_s,
                 :userid       => session[:userid]}
        AuditEvent.success(audit)
      end
      model.destroy_queue(emss)
      add_flash(_("Delete initiated for %{count_model} from the CFME Database") %
        {:count_model => pluralize(emss.length, ui_lookup(:table => @table_name))}) if @flash_array.nil?
    else
      model.where(:id => emss).order("lower(name)").each do |ems|
        id = ems.id
        ems_name = ems.name
        if task == "destroy"
          audit = {:event     => "ems_record_delete",
                   :message   => _("[%{name}] Record deleted") % {:name => ems_name},
                   :target_id => id, :target_class => model.to_s,
                   :userid    => session[:userid]}
        end
        begin
          ems.send(task.to_sym) if ems.respond_to?(task)    # Run the task
        rescue StandardError => bang
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': %{error_message}") %
            {:model => model.to_s, :name => ems_name, :task => task, :error_message => bang.message}, :error)
          AuditEvent.failure(:userid => session[:userid], :event => "#{@table_name}_#{task}",
            :message      => _("%{name}: Error during '%{task}': %{message}") %
                          {:name => ems_name, :task => task, :message => bang.message},
            :target_class => model.to_s, :target_id => id)
        else
          if task == "destroy"
            AuditEvent.success(audit)
            add_flash(_("%{model} \"%{name}\": Delete successful") % {:model => ui_lookup(:model => model.to_s), :name => ems_name})
            AuditEvent.success(:userid => session[:userid], :event => "#{@table_name}_#{task}",
              :message      => _("%{name}: Delete successful") % {:name => ems_name},
              :target_class => model.to_s, :target_id => id)
          else
            add_flash(_("%{model} \"%{name}\": %{task} successfully initiated") % {:model => model.to_s, :name => ems_name, :task => task})
            AuditEvent.success(:userid => session[:userid], :event => "#{@table_name}_#{task}",
              :message      => _("%{name}: '%{task}' successfully initiated") % {:name => ems_name, :task => task},
              :target_class => model.to_s, :target_id => id)
          end
        end
      end
    end
  end

  # Delete all selected or single displayed ems(s)
  def deleteemss
    assert_privileges(params[:pressed])
    emss = []
    if @lastaction == "show_list" # showing a list, scan all selected emss
      emss = find_checked_items
      if emss.empty?
        add_flash(_("No %{record} were selected for deletion") % {:record => ui_lookup(:table => @table_name)}, :error)
      end
      process_emss(emss, "destroy") unless emss.empty?
      add_flash(_("Delete initiated for %{count_model} from the CFME Database") %
        {:count_model => pluralize(emss.length, ui_lookup(:table => @table_name))}) if @flash_array.nil?
    else # showing 1 ems, scan it
      if params[:id].nil? || model.find_by_id(params[:id]).nil?
        add_flash(_("%{record} no longer exists") % {:record => ui_lookup(:table => @table_name)}, :error)
      else
        emss.push(params[:id])
      end
      process_emss(emss, "destroy") unless emss.empty?
      @single_delete = true unless flash_errors?
      add_flash(_("The selected %{record} was deleted") %
        {:record => ui_lookup(:tables => @table_name)}) if @flash_array.nil?
    end
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    end
  end

  # Scan all selected or single displayed ems(s)
  def scanemss
    assert_privileges(params[:pressed])
    emss = []
    if @lastaction == "show_list" # showing a list, scan all selected emss
      emss = find_checked_items
      if emss.empty?
        add_flash(_("No %{model} were selected for scanning") % {:model => ui_lookup(:table => @table_name)}, :error)
      end
      process_emss(emss, "scan")  unless emss.empty?
      add_flash(_("Analysis initiated for %{count_model} from the CFME Database") %
        {:count_model => pluralize(emss.length, ui_lookup(:tables => @table_name))}) if @flash_array.nil?
      show_list
      @refresh_partial = "layouts/gtl"
    else # showing 1 ems, scan it
      if params[:id].nil? || model.find_by_id(params[:id]).nil?
        add_flash(_("%{record} no longer exists") % {:record => ui_lookup(:tables => @table_name)}, :error)
      else
        emss.push(params[:id])
      end
      process_emss(emss, "scan")  unless emss.empty?
      add_flash(_("Analysis initiated for %{count_model} from the CFME Database") %
        {:count_model => pluralize(emss.length, ui_lookup(:tables => @table_name))}) if @flash_array.nil?
      params[:display] = @display
      show
      if ["vms", "hosts", "storages"].include?(@display)
        @refresh_partial = "layouts/gtl"
      else
        @refresh_partial = "main"
      end
    end
  end

  # Refresh VM states for all selected or single displayed ems(s)
  def refreshemss
    assert_privileges(params[:pressed])
    emss = []
    if @lastaction == "show_list" # showing a list, scan all selected emss
      emss = find_checked_items
      if emss.empty?
        add_flash(_("No %{model} were selected for refresh") % {:model => ui_lookup(:table => @table_name)}, :error)
      end
      process_emss(emss, "refresh_ems") unless emss.empty?
      add_flash(_("Refresh initiated for %{count_model} from the CFME Database") %
        {:count_model => pluralize(emss.length, ui_lookup(:tables => @table_name))}) if @flash_array.nil?
      show_list
      @refresh_partial = "layouts/gtl"
    else # showing 1 ems, scan it
      if params[:id].nil? || model.find_by_id(params[:id]).nil?
        add_flash(_("%{record} no longer exists") % {:record => ui_lookup(:table => @table_name)}, :error)
      else
        emss.push(params[:id])
      end
      process_emss(emss, "refresh_ems") unless emss.empty?
      add_flash(_("Refresh initiated for %{count_model} from the CFME Database") %
        {:count_model => pluralize(emss.length, ui_lookup(:tables => @table_name))}) if @flash_array.nil?
      params[:display] = @display
      show
      if ["vms", "hosts", "storages"].include?(@display)
        @refresh_partial = "layouts/gtl"
      else
        @refresh_partial = "main"
      end
    end
  end

  # true, if any of the given fields are either missing from or blank in hash
  def any_blank_fields?(hash, fields)
    fields = [fields] unless fields.kind_of? Array
    fields.any? { |f| !hash.key?(f) || hash[f].blank? }
  end

  def get_session_data
    prefix      = self.class.session_key_prefix
    @title      = ui_lookup(:tables => prefix)
    @layout     = prefix
    @table_name = request.parameters[:controller]
    @lastaction = session["#{prefix}_lastaction".to_sym]
    @display    = session["#{prefix}_display".to_sym]
    @filters    = session["#{prefix}_filters".to_sym]
    @catinfo    = session["#{prefix}_catinfo".to_sym]
  end

  def set_session_data
    prefix                                 = self.class.session_key_prefix
    session["#{prefix}_lastaction".to_sym] = @lastaction
    session["#{prefix}_display".to_sym]    = @display unless @display.nil?
    session["#{prefix}_filters".to_sym]    = @filters
    session["#{prefix}_catinfo".to_sym]    = @catinfo
  end

  def model
    self.class.model
  end

  def permission_prefix
    self.class.permission_prefix
  end

  def show_link(ems, options = {})
    url_for(options.merge(:controller => @table_name,
                          :action     => "show",
                          :id         => ems.id,
                          :only_path  => true))
  end

  def restore_password
    if params[:default_password]
      @edit[:new][:default_password] = @edit[:new][:default_verify] = @ems.authentication_password
    end
    if params[:amqp_password]
      @edit[:new][:amqp_password] = @edit[:new][:amqp_verify] = @ems.authentication_password(:amqp)
    end
    if params[:metrics_password]
      @edit[:new][:metrics_password] = @edit[:new][:metrics_verify] = @ems.authentication_password(:metrics)
    end
    if params[:bearer_token]
      @edit[:new][:bearer_token] = @edit[:new][:bearer_verify] = @ems.authentication_token(:bearer)
    end
  end
end
