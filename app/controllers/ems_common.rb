module EmsCommon
  extend ActiveSupport::Concern

  def show
    @display = params[:display] || "main" unless control_selected?

    session[:vm_summary_cool] = (@settings[:views][:vm_summary_cool] == "summary")
    @summary_view = session[:vm_summary_cool]
    @ems = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@ems)

    @gtl_url = show_link(@ems) << "?"
    @showtype = "config"
    drop_breadcrumb({:name=>ui_lookup(:tables=>@table_name), :url=>"/#{@table_name}/show_list?page=#{@current_page}&refresh=y"}, true)

    if ["download_pdf","main","summary_only"].include?(@display)
      get_tagdata(@ems)
      drop_breadcrumb(:name => @ems.name + " (Summary)", :url => show_link(@ems))
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)
    elsif @display == "props"
      drop_breadcrumb(:name => @ems.name+" (Properties)", :url => show_link(@ems, :display  =>  "props"))
    elsif @display == "ems_folders"
      if params[:vat]
        drop_breadcrumb(:name => @ems.name+" (VMs & Templates)",
                        :url  => show_link(@ems, :display  =>  "ems_folder", :vat  =>  "true"))
      else
        drop_breadcrumb(:name => @ems.name+" (Hosts & Clusters)",
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
      drop_breadcrumb(:name => "Timelines", :url => show_link(@record.id, :refresh => "n", :display => "timeline"))
    elsif ["instances","images","miq_templates","vms"].include?(@display) || session[:display] == "vms" && params[:display].nil?
      if @display == "instances"
        title = "Instances"
        kls = ManageIQ::Providers::CloudManager::Vm
      elsif @display == "images"
        title = "Images"
        kls = ManageIQ::Providers::CloudManager::Template
      elsif @display == "miq_templates"
        title = "Templates"
        kls = MiqTemplate
      elsif @display == "vms"
        title = "VMs"
        kls = Vm
      end
      drop_breadcrumb(:name => @ems.name+" (All #{title})", :url => show_link(@ems, :display  =>  @display))
      @view, @pages = get_view(kls, :parent=>@ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this " + ui_lookup(:tables=>@table_name)
      end
    elsif @display == "availability_zones" || session[:display] == "availability_zones" && params[:display].nil?
      title = "Availability Zones"
      drop_breadcrumb(:name => @ems.name+" (All #{title})", :url => show_link(@ems, :display => @display))
      @view, @pages = get_view(AvailabilityZone, :parent=>@ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this " + ui_lookup(:tables=>@table_name)
      end
    elsif @display == "container_replicators" || session[:display] == "container_replicators" && params[:display].nil?
      title = ui_lookup(:tables => "container_replicators")
      drop_breadcrumb(:name => @ems.name + " (All #{title})",
                      :url  => "/#{@table_name}/show/#{@ems.id}?display=#{@display}")
      @view, @pages = get_view(ContainerReplicator, :parent => @ems)
      @showtype = @display
      if @view.extras[:total_count] > @view.extras[:auth_count] && @view.extras[:total_count] &&
         @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " +
                      pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") +
                      " on this " + ui_lookup(:tables => @table_name)
      end
    elsif @display == "containers" || session[:display] == "containers" && params[:display].nil?
      title = ui_lookup(:tables => "containers")
      drop_breadcrumb(:name => @ems.name + " (All #{title})",
                      :url  => "/#{@table_name}/show/#{@ems.id}?display=#{@display}")
      @view, @pages = get_view(Container, :parent => @ems)
      @showtype = @display
      if @view.extras[:total_count] > @view.extras[:auth_count] && @view.extras[:total_count] &&
         @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " +
                      pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") +
                      " on this " + ui_lookup(:tables => @table_name)
      end
    elsif @display == "container_nodes" || session[:display] == "container_nodes" && params[:display].nil?
      title = "Container Nodes"
      drop_breadcrumb(:name => @ems.name + " (All #{title})",
                      :url  => "/#{@table_name}/show/#{@ems.id}?display=#{@display}")
      @view, @pages = get_view(ContainerNode, :parent => @ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] > @view.extras[:auth_count] && @view.extras[:total_count] &&
         @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " +
                      pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") +
                      " on this " + ui_lookup(:tables => @table_name)
      end
    elsif @display == "container_services" || session[:display] == "container_services" && params[:display].nil?
      title = "Container Services"
      drop_breadcrumb(:name => @ems.name + " (All #{title})",
                      :url  => "/#{@table_name}/show/#{@ems.id}?display=#{@display}")
      @view, @pages = get_view(ContainerService, :parent => @ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] > @view.extras[:auth_count] && @view.extras[:total_count] &&
         @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " +
                      pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") +
                      " on this " + ui_lookup(:tables => @table_name)
      end
    elsif @display == "container_groups" || session[:display] == "container_groups" && params[:display].nil?
      title = "Pods"
      drop_breadcrumb(:name => @ems.name + " (All #{title})",
                      :url  => "/#{@table_name}/show/#{@ems.id}?display=#{@display}")
      @view, @pages = get_view(ContainerGroup, :parent => @ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] > @view.extras[:auth_count] && @view.extras[:total_count] &&
         @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " +
                      pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") +
                      " on this " + ui_lookup(:tables => @table_name)
      end
    elsif @display == "container_routes" || session[:display] == "container_routes" && params[:display].nil?
      title = ui_lookup(:tables => "container_routes")
      drop_breadcrumb(:name => @ems.name + " (All #{title})",
                      :url  => "/#{@table_name}/show/#{@ems.id}?display=#{@display}")
      @view, @pages = get_view(ContainerRoute, :parent => @ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] > @view.extras[:auth_count] && @view.extras[:total_count] &&
         @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " +
                      pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") +
                      " on this " + ui_lookup(:tables => @table_name)
      end
    elsif @display == "container_projects" || session[:display] == "container_projects" && params[:display].nil?
      title = ui_lookup(:tables => "container_projects")
      drop_breadcrumb(:name => @ems.name + " (All #{title})",
                      :url  => "/#{@table_name}/show/#{@ems.id}?display=#{@display}")
      @view, @pages = get_view(ContainerProject, :parent => @ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] > @view.extras[:auth_count] && @view.extras[:total_count] &&
         @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " +
                      pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") +
                      " on this " + ui_lookup(:tables => @table_name)
      end
    elsif @display == "container_image_registries" ||
          session[:display] == "container_image_registries" && params[:display].nil?
      title = ui_lookup(:tables => "container_image_registries")
      drop_breadcrumb(:name => @ems.name + " (All #{title})",
                      :url  => "/#{@table_name}/show/#{@ems.id}?display=#{@display}")
      @view, @pages = get_view(ContainerImageRegistry, :parent => @ems)  # Get the records into a view and the paginator
      @showtype = @display
      if @view.extras[:total_count] > @view.extras[:auth_count] && @view.extras[:total_count] &&
         @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " +
                      pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") +
                      " on this " + ui_lookup(:tables => @table_name)
      end
    elsif @display == "container_images" || session[:display] == "container_images" && params[:display].nil?
      title = ui_lookup(:tables => "container_images")
      drop_breadcrumb(:name => @ems.name + " (All #{title})",
                      :url  => "/#{@table_name}/show/#{@ems.id}?display=#{@display}")
      @view, @pages = get_view(ContainerImage, :parent => @ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] > @view.extras[:auth_count] && @view.extras[:total_count] &&
         @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " +
                      pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") +
                      " on this " + ui_lookup(:tables => @table_name)
      end
    elsif @display == "cloud_tenants" || (session[:display] == "cloud_tenants" && params[:display].nil?)
      title = "Cloud Tenants"
      drop_breadcrumb(:name => "#{@ems.name} (All #{title})", :url => show_link(@ems, :display => @display))
      @view, @pages = get_view(CloudTenant, :parent => @ems) # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] && @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this " + ui_lookup(:tables => @table_name)
      end
    elsif @display == "flavors" || session[:display] == "flavors" && params[:display].nil?
      title = "Flavors"
      drop_breadcrumb(:name => @ems.name+" (All #{title})", :url => show_link(@ems, :display => @display))
      @view, @pages = get_view(Flavor, :parent=>@ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this " + ui_lookup(:tables=>@table_name)
      end
    elsif @display == "security_groups" || session[:display] == "security_groups" && params[:display].nil?
      title = "Security Groups"
      drop_breadcrumb(:name => @ems.name+" (All #{title})", :url => show_link(@ems, :display => @display))
      @view, @pages = get_view(SecurityGroup, :parent=>@ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}") + " on this " + ui_lookup(:tables=>@table_name)
      end
    elsif @display == "storages" || session[:display] == "storages" && params[:display].nil?
      drop_breadcrumb(:name => @ems.name+" (All Managed #{ui_lookup(:tables => "storages")})", :url => show_link(@ems, :display => "storages"))
      @view, @pages = get_view(Storage, :parent=>@ems)  # Get the records (into a view) and the paginator
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other " + ui_lookup(:table=>"storages")) + " on this " + ui_lookup(:table=>@table_name)
      end
    elsif @display == "ems_clusters"
      drop_breadcrumb(:name => "#{@ems.name} (All #{title_for_clusters})",
                      :url  => show_link(@ems, :display => "ems_clusters"))
      @view, @pages = get_view(EmsCluster, :parent=>@ems) # Get the records (into a view) and the paginator
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other Cluster") + " on this " + ui_lookup(:tables=>@table_name)
      end
    elsif @display == "orchestration_stacks" || session[:display] == "orchestration_stacks" && params[:display].nil?
      title = "Stacks"
      drop_breadcrumb(:name => "#{@ems.name} (All #{title})",
                      :url  => show_link(@ems, :display => @display))
      @view, @pages = get_view(OrchestrationStack, :parent => @ems)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] &&
         @view.extras[:auth_count] &&
         @view.extras[:total_count] > @view.extras[:auth_count]
        count_text = pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}")
        @bottom_msg = "* You are not authorized to view #{count_text} on this #{ui_lookup(:tables => @table_name)}"
      end
    else  # Must be Hosts # FIXME !!!
      drop_breadcrumb(:name => @ems.name + " (All Managed Hosts)", :url => show_link(@ems, :display => :hosts))
      @view, @pages = get_view(Host, :parent=>@ems) # Get the records (into a view) and the paginator
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other Host") + " on this " + ui_lookup(:tables=>@table_name)
      end
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
    process_show_list
  end

  def new
    assert_privileges("#{permission_prefix}_new")
    @ems = model.new
    set_form_vars
    @in_a_form = true
    session[:changed] = nil
    drop_breadcrumb( {:name=>"Add New #{ui_lookup(:table=>@table_name)}", :url=>"/#{@table_name}/new"} )
  end

  def create
    assert_privileges("#{permission_prefix}_new")
    return unless load_edit("ems_edit__new")
    get_form_vars
    case params[:button]
    when "add"
      if @edit[:new][:emstype].blank?
        add_flash(_("%s is required") % "Type", :error)
      end

      if @edit[:new][:emstype] == "scvmm" && @edit[:new][:security_protocol] == "kerberos" && @edit[:new][:realm].blank?
        add_flash(_("%s is required") % "Realm", :error)
      end

      if !@flash_array
        add_ems = model.model_from_emstype(@edit[:new][:emstype]).new
        set_record_vars(add_ems)
      end
      if !@flash_array && valid_record?(add_ems) && add_ems.save
        AuditEvent.success(build_created_audit(add_ems, @edit))
        session[:edit] = nil  # Clear the edit object from the session object
        render :update do |page|
          page.redirect_to :action=>'show_list', :flash_msg=>_("%{model} \"%{name}\" was saved") % {:model=>ui_lookup(:tables=>@table_name), :name=>add_ems.name}
        end
      else
        @in_a_form = true
        if !@flash_array
          @edit[:errors].each { |msg| add_flash(msg, :error) }
          add_ems.errors.each do |field,msg|
            add_flash("#{add_ems.class.human_attribute_name(field)} #{msg}", :error)
          end
        end
        drop_breadcrumb( {:name=>"Add New #{ui_lookup(:table=>@table_name)}", :url=>"/#{@table_name}/new"} )
        render :update do |page|
          page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        end
      end
    when "validate"
      verify_ems = model.model_from_emstype(@edit[:new][:emstype]).new
      validate_credentials verify_ems
    end
  end

  def edit
    assert_privileges("#{permission_prefix}_edit")
    @ems = find_by_id_filtered(model, params[:id])
    set_form_vars
    @in_a_form = true
    session[:changed] = false
    drop_breadcrumb( {:name=>"Edit #{ui_lookup(:tables=>@table_name)} '#{@ems.name}'", :url=>"/#{@table_name}/edit/#{@ems.id}"} )
  end

  # AJAX driven routine to check for changes in ANY field on the form
  def form_field_changed
    return unless load_edit("ems_edit__#{params[:id]}")
    get_form_vars

    changed = edit_changed?
    render :update do |page|                  # Use JS to update the display
      if params[:server_emstype] || params[:security_protocol]   # Server/protocol type changed
        page.replace_html("form_div", :partial => "shared/views/ems_common/form")
      end
      if params[:server_emstype]              # Server type changed
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
        page.redirect_to :action => 'show', :id => @ems.id.to_s, :flash_msg => flash
      end
      return
    else
      @edit[:errors].each { |msg| add_flash(msg, :error) }
      update_ems.errors.each do |field, msg|
        add_flash("#{field.to_s.capitalize} #{msg}", :error)
      end
      drop_breadcrumb(:name => "Edit #{ui_lookup(:table => @table_name)} '#{@ems.name}'",
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
      add_flash(_("Credential validation was not successful: %s") % details, :error)
    end

    render_flash
  end
  private :validate_credentials

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["vms","hosts","storages", "instances", "images"].include?(@display)  # Were we displaying vms/hosts/storages
    params[:page] = @current_page if @current_page != nil   # Save current page for list refresh

    if params[:pressed].starts_with?("vm_") ||        # Handle buttons from sub-items screen
        params[:pressed].starts_with?("miq_template_") ||
        params[:pressed].starts_with?("guest_") ||
        params[:pressed].starts_with?("image_") ||
        params[:pressed].starts_with?("instance_") ||
        params[:pressed].starts_with?("storage_") ||
        params[:pressed].starts_with?("ems_cluster_") ||
        params[:pressed].starts_with?("host_")

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

      terminatevms if params[:pressed] == "instance_terminate"

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      # Handle Host power buttons
      if ["host_shutdown","host_reboot","host_standby","host_enter_maint_mode","host_exit_maint_mode",
          "host_start","host_stop","host_reset"].include?(params[:pressed])
        powerbutton_hosts(params[:pressed].split("_")[1..-1].join("_")) # Handle specific power button
      else
        process_vm_buttons(pfx)
        # Control transferred to another screen, so return
        return if ["host_tag", "#{pfx}_policy_sim", "host_scan", "host_refresh","host_protect",
                    "host_compare","#{pfx}_compare", "#{pfx}_tag","#{pfx}_retire",
                    "#{pfx}_protect","#{pfx}_ownership", "#{pfx}_refresh","#{pfx}_right_size",
                    "#{pfx}_reconfigure","storage_tag","ems_cluster_compare",
                    "ems_cluster_protect","ems_cluster_tag"].include?(params[:pressed]) &&
                    @flash_array == nil

        if !["host_edit","#{pfx}_edit","#{pfx}_miq_request_new","#{pfx}_clone",
             "#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
          @refresh_div = "main_div"
          @refresh_partial = "layouts/gtl"
          show                                                        # Handle EMS buttons
        end
      end
    else
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      redirect_to :action=>"new" if params[:pressed] == "new"
      deleteemss if params[:pressed] == "#{@table_name}_delete"
      refreshemss if params[:pressed] == "#{@table_name}_refresh"
#     scanemss if params[:pressed] == "scan"
      tag(model) if params[:pressed] == "#{@table_name}_tag"
      assign_policies(model) if params[:pressed] == "#{@table_name}_protect"
      edit_record if params[:pressed] == "#{@table_name}_edit"
      custom_buttons if params[:pressed] == "custom_button"

      return if ["custom_button"].include?(params[:pressed])    # custom button screen, so return, let custom_buttons method handle everything
      return if ["#{@table_name}_tag","#{@table_name}_protect"].include?(params[:pressed]) &&
                @flash_array == nil # Tag screen showing, so return

      check_if_button_is_implemented
    end

    if !@flash_array.nil? && params[:pressed] == "#{@table_name}_delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to build the retire screen
      end
    elsif params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new","#{pfx}_clone",
                                                   "#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
      if @redirect_controller
        if ["#{pfx}_clone","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id, :prov_type=>@prov_type, :prov_id=>@prov_id
          end
        else
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id
          end
        end
      else
        if params[:pressed] == "ems_cloud_edit"
          render :update do |page|
            page.redirect_to edit_ems_cloud_path(params[:id])
          end
        else
          render :update do |page|
            page.redirect_to :action=>@refresh_partial, :id=>@redirect_id
          end
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
              if ["vms","hosts","storages","ems_clusters"].include?(@display) # If displaying vms, action_url s/b show
                page << "miqReinitToolbar('center_tb');"
                page.replace_html("main_div", :partial=>"layouts/gtl", :locals=>{:action_url=>"show/#{@ems.id}"})
              else
                page.replace_html(@refresh_div, :partial=>@refresh_partial)
              end
            end
          end
        end
      end
    end

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
    @sb[:vat] = false if params[:action] != "treesize"        #need to set this, to remember vat, treesize doesnt pass in param[:vat]
    vat = params[:vat] ? true : (@sb[:vat] ? true : false)    #use @sb[:vat] when coming from treesize
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
    build_vm_host_array if %w{show treesize}.include?(params[:action])
  end

  # Add the children of a node that is being expanded (autoloaded)
  def tree_add_child_nodes(id)
    get_dc_child_nodes(id)
  end

  # Validate the ems record fields
  def valid_record?(ems)
    @edit[:errors] = Array.new
    if ems.emstype == "scvmm" && ems.security_protocol == "kerberos" && ems.realm.blank?
      add_flash(_("%s is required") % "Realm", :error)
    end
    if !ems.authentication_password.blank? && ems.authentication_userid.blank?
      @edit[:errors].push(_("Username must be entered if Password is entered"))
    end
    if @edit[:new][:password] != @edit[:new][:verify]
      @edit[:errors].push(_("Password/Verify Password do not match"))
    end
    if ems.supports_authentication?(:metrics) && @edit[:new][:metrics_password] != @edit[:new][:metrics_verify]
      @edit[:errors].push("C & U Database Login Password and Verify Password fields do not match")
    end
    if ems.is_a?(ManageIQ::Providers::Vmware::InfraManager)
      unless @edit[:new][:host_default_vnc_port_start] =~ /^\d+$/ || @edit[:new][:host_default_vnc_port_start].blank?
        @edit[:errors].push(_("%s must be numeric") % "Default Host VNC Port Range Start")
      end
      unless @edit[:new][:host_default_vnc_port_end] =~ /^\d+$/ || @edit[:new][:host_default_vnc_port_end].blank?
        @edit[:errors].push(_("%s must be numeric") % "Default Host VNC Port Range End")
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
    return @edit[:errors].empty?
  end

  # Set form variables for edit
  def set_form_vars

    @edit = Hash.new
    @edit[:ems_id] = @ems.id
    @edit[:key] = "ems_edit__#{@ems.id || "new"}"
    @edit[:new] = Hash.new
    @edit[:current] = Hash.new

    @edit[:new][:name] = @ems.name
    @edit[:new][:provider_region] = @ems.provider_region
    @edit[:new][:hostname] = @ems.hostname
    @edit[:new][:emstype] = @ems.emstype
    @edit[:amazon_regions] = get_amazon_regions if @ems.kind_of?(ManageIQ::Providers::Amazon::CloudManager)
    @edit[:new][:port] = @ems.port
    @edit[:new][:provider_id] = @ems.provider_id
    @edit[:protocols] = [['Basic (SSL)', 'ssl'], ['Kerberos', 'kerberos']]
    if @ems.id
      # for existing provider before this fix, set default to ssl
      @edit[:new][:security_protocol] = @ems.security_protocol ? @ems.security_protocol : 'ssl'
    else
      @edit[:new][:security_protocol] = 'kerberos'
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

    if @ems.is_a?(ManageIQ::Providers::Vmware::InfraManager)
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

  def get_amazon_regions
    regions = Hash.new
    ManageIQ::Providers::Amazon::Regions.all.each do |region|
      regions[region[:name]] = region[:description]
    end
    return regions
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
      elsif params[:server_emstype] == ManageIQ::Providers::Kubernetes::ContainerManager.ems_type
        @edit[:new][:port] = @ems.port ? @ems.port : ManageIQ::Providers::Kubernetes::ContainerManager::DEFAULT_PORT
      elsif params[:server_emstype] == ManageIQ::Providers::Openshift::ContainerManager.ems_type
        @edit[:new][:port] = @ems.port ? @ems.port : ManageIQ::Providers::Openshift::ContainerManager::DEFAULT_PORT
      else
        @edit[:new][:port] = nil
      end
    end
    @edit[:new][:port] = params[:port] if params[:port]
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
    @edit[:amazon_regions] = get_amazon_regions if @edit[:new][:emstype] == "ec2"
    @edit[:new][:security_protocol] = params[:security_protocol] if params[:security_protocol]
    @edit[:new][:realm] = nil if params[:security_protocol]
    @edit[:new][:realm] = params[:realm] if params[:realm]
    set_verify_status
  end

  # Set record variables to new values
  def set_record_vars(ems, mode = nil)
    ems.name = @edit[:new][:name]
    ems.provider_region = @edit[:new][:provider_region]
    ems.hostname = @edit[:new][:hostname].strip unless @edit[:new][:hostname].nil?
    ems.port = @edit[:new][:port] if ems.supports_port?
    ems.provider_id = @edit[:new][:provider_id] if ems.supports_provider_id?
    ems.zone = Zone.find_by_name(@edit[:new][:zone])

    if ems.is_a?(ManageIQ::Providers::Microsoft::InfraManager)
      ems.security_protocol = @edit[:new][:security_protocol]
      ems.realm = @edit[:new][:realm]
    end

    if ems.is_a?(ManageIQ::Providers::Vmware::InfraManager)
      ems.host_default_vnc_port_start = @edit[:new][:host_default_vnc_port_start].blank? ? nil : @edit[:new][:host_default_vnc_port_start].to_i
      ems.host_default_vnc_port_end = @edit[:new][:host_default_vnc_port_end].blank? ? nil : @edit[:new][:host_default_vnc_port_end].to_i
    end

    creds = Hash.new
    creds[:default] = {:userid=>@edit[:new][:default_userid], :password=>@edit[:new][:default_password]} unless @edit[:new][:default_userid].blank?
    if ems.supports_authentication?(:metrics) && !@edit[:new][:metrics_userid].blank?
      creds[:metrics] = {:userid=>@edit[:new][:metrics_userid], :password=>@edit[:new][:metrics_password]}
    end
    if ems.supports_authentication?(:amqp) && !@edit[:new][:amqp_userid].blank?
      creds[:amqp] = {:userid => @edit[:new][:amqp_userid], :password => @edit[:new][:amqp_password]}
    end
    if ems.supports_authentication?(:ssh_keypair) && !@edit[:new][:ssh_keypair_userid].blank?
      creds[:ssh_keypair] = {:userid => @edit[:new][:ssh_keypair_userid], :auth_key => @edit[:new][:ssh_keypair_password]}
    end
    if ems.supports_authentication?(:bearer) && !@edit[:new][:bearer_token].blank?
      creds[:bearer] = {:auth_key => @edit[:new][:bearer_token], :userid => "_"} # Must have userid
    end
    ems.update_authentication(creds, {:save=>(mode != :validate)})
  end

  def process_emss(emss, task)
    emss, emss_out_region = filter_ids_in_region(emss, "Provider")
    return if emss.empty?

    if task == "refresh_ems"
      model.refresh_ems(emss, true)
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>Dictionary::gettext(task, :type=>:task).titleize.gsub("Ems","#{ui_lookup(:tables=>@table_name)}"), :count_model=>pluralize(emss.length,ui_lookup(:table=>@table_name))})
      AuditEvent.success(:userid=>session[:userid],:event=>"#{@table_name}_#{task}",
          :message=>"'#{task}' successfully initiated for #{pluralize(emss.length,"#{ui_lookup(:tables=>@table_name)}")}",
          :target_class=>model.to_s)
    elsif task == "destroy"
      model.find_all_by_id(emss, :order => "lower(name)").each do |ems|
        id = ems.id
        ems_name = ems.name
        audit = {:event=>"ems_record_delete_initiated", :message=>"[#{ems_name}] Record delete initiated", :target_id=>id, :target_class=>model.to_s, :userid => session[:userid]}
        AuditEvent.success(audit)
      end
      model.destroy_queue(emss)
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Delete", :count_model=>pluralize(emss.length,ui_lookup(:table=>@table_name))}) if @flash_array == nil
    else
      model.find_all_by_id(emss, :order => "lower(name)").each do |ems|
        id = ems.id
        ems_name = ems.name
        if task == "destroy"
          audit = {:event=>"ems_record_delete", :message=>"[#{ems_name}] Record deleted", :target_id=>id, :target_class=>model.to_s, :userid => session[:userid]}
        end
        begin
          ems.send(task.to_sym) if ems.respond_to?(task)    # Run the task
        rescue StandardError => bang
          add_flash(_("%{model} \"%{name}\": Error during '%{task}': ") % {:model=>model.to_s, :name=>ems_name, :task=>task} << bang.message,
                    :error)
          AuditEvent.failure(:userid=>session[:userid],:event=>"#{@table_name}_#{task}",
            :message=>"#{ems_name}: Error during '" << task << "': " << bang.message,
            :target_class=>model.to_s, :target_id=>id)
        else
          if task == "destroy"
            AuditEvent.success(audit)
            add_flash(_("%{model} \"%{name}\": Delete successful") % {:model=>ui_lookup(:model=>model.to_s), :name=>ems_name})
            AuditEvent.success(:userid=>session[:userid],:event=>"#{@table_name}_#{task}",
              :message=>"#{ems_name}: Delete successful",
              :target_class=>model.to_s, :target_id=>id)
          else
            add_flash(_("%{model} \"%{name}\": %{task} successfully initiated") % {:model=>model.to_s, :name=>ems_name, :task=>task})
            AuditEvent.success(:userid=>session[:userid],:event=>"#{@table_name}_#{task}",
              :message=>"#{ems_name}: '" + task + "' successfully initiated",
              :target_class=>model.to_s, :target_id=>id)
          end
        end
      end
    end
  end

  # Delete all selected or single displayed ems(s)
  def deleteemss
    assert_privileges(params[:pressed])
    emss = Array.new
    if @lastaction == "show_list" # showing a list, scan all selected emss
      emss = find_checked_items
      if emss.empty?
        add_flash(_("No %s were selected for deletion") % ui_lookup(:table=>@table_name), :error)
      end
      process_emss(emss, "destroy") if ! emss.empty?
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Delete", :count_model=>pluralize(emss.length,ui_lookup(:table=>@table_name))}) if @flash_array == nil
    else # showing 1 ems, scan it
      if params[:id] == nil || model.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:table=>@table_name), :error)
      else
        emss.push(params[:id])
      end
      process_emss(emss, "destroy") if ! emss.empty?
      @single_delete = true unless flash_errors?
      add_flash(_("The selected %s was deleted") % ui_lookup(:tables=>@table_name)) if @flash_array == nil
    end
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    end
  end

  # Scan all selected or single displayed ems(s)
  def scanemss
    assert_privileges(params[:pressed])
    emss = Array.new
    if @lastaction == "show_list" # showing a list, scan all selected emss
      emss = find_checked_items
      if emss.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:table=>@table_name), :task=>"scanning"}, :error)
      end
      process_emss(emss, "scan")  if ! emss.empty?
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Analysis", :count_model=>pluralize(emss.length,ui_lookup(:tables=>@table_name))})if @flash_array == nil
      show_list
      @refresh_partial = "layouts/gtl"
    else # showing 1 ems, scan it
      if params[:id] == nil || model.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:tables=>@table_name), :error)
      else
        emss.push(params[:id])
      end
      process_emss(emss, "scan")  if ! emss.empty?
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Analysis", :count_model=>pluralize(emss.length,ui_lookup(:tables=>@table_name))})if @flash_array == nil
      params[:display] = @display
      show
      if ["vms","hosts","storages"].include?(@display)
        @refresh_partial = "layouts/gtl"
      else
        @refresh_partial = "main"
      end
    end
  end

  # Refresh VM states for all selected or single displayed ems(s)
  def refreshemss
    assert_privileges(params[:pressed])
    emss = Array.new
    if @lastaction == "show_list" # showing a list, scan all selected emss
      emss = find_checked_items
      if emss.empty?
        add_flash(_("No %{model} were selected for %{task}") % {:model=>ui_lookup(:table=>@table_name), :task=>"refresh"}, :error)
      end
      process_emss(emss, "refresh_ems") if ! emss.empty?
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Refresh", :count_model=>pluralize(emss.length,ui_lookup(:tables=>@table_name))}) if @flash_array == nil
      show_list
      @refresh_partial = "layouts/gtl"
    else # showing 1 ems, scan it
      if params[:id] == nil || model.find_by_id(params[:id]).nil?
        add_flash(_("%s no longer exists") % ui_lookup(:table=>@table_name), :error)
      else
        emss.push(params[:id])
      end
      process_emss(emss, "refresh_ems") if ! emss.empty?
      add_flash(_("%{task} initiated for %{count_model} from the CFME Database") % {:task=>"Refresh", :count_model=>pluralize(emss.length,ui_lookup(:tables=>@table_name))})if @flash_array == nil
      params[:display] = @display
      show
      if ["vms","hosts","storages"].include?(@display)
        @refresh_partial = "layouts/gtl"
      else
        @refresh_partial = "main"
      end
    end
  end

  # true, if any of the given fields are either missing from or blank in hash
  def any_blank_fields?(hash, fields)
    fields = [fields] unless fields.is_a? Array
    fields.any? {|f| !hash.has_key?(f) || hash[f].blank? }
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
                          :id         => ems.id))
  end

  def permission_prefix
    self.class.permission_prefix
  end
end
