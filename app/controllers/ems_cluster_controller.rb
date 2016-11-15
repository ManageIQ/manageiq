class EmsClusterController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin

  def drift_history
    @display = "drift_history"
    super
  end

  def show
    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype = "config"
    @ems_cluster = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@ems_cluster)

    @gtl_url = "/show"

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@ems_cluster)
      drop_breadcrumb({:name => _("Clusters"), :url => "/ems_cluster/show_list?page=#{@current_page}&refresh=y"}, true)
      drop_breadcrumb(:name => @ems_cluster.name + _(" (Summary)"), :url => "/ems_cluster/show/#{@ems_cluster.id}")
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)

    when "descendant_vms"
      drop_breadcrumb(:name => @ems_cluster.name + _(" (All VMs - Tree View)"),
                      :url  => "/ems_cluster/show/#{@ems_cluster.id}?display=descendant_vms&treestate=true")
      @showtype = "config"

      cluster = @ems_cluster
      @datacenter_tree = TreeBuilderDatacenter.new(:datacenter_tree, :datacenter, @sb, true, cluster)
      self.x_active_tree = :datacenter_tree

    when "all_vms"
      drop_breadcrumb(:name => @ems_cluster.name + _(" (All VMs)"),
                      :url  => "/ems_cluster/show/#{@ems_cluster.id}?display=all_vms")
      @view, @pages = get_view(Vm, :parent => @ems_cluster, :association => "all_vms")  # Get the records (into a view) and the paginator
      @showtype = "vms"

    when "miq_templates", "vms"
      title, kls = @display == "vms" ? ["VMs", Vm] : ["Templates", MiqTemplate]
      drop_breadcrumb(:name => @ems_cluster.name + _(" (Direct %{title})") % {:title => title},
                      :url  => "/ems_cluster/show/#{@ems_cluster.id}?display=#{@display}")
      @view, @pages = get_view(kls, :parent => @ems_cluster)  # Get the records (into a view) and the paginator
      @showtype = @display

    when "hosts"
      label, condition, breadcrumb_suffix = hosts_subsets

      drop_breadcrumb(:name => label, :url => "/ems_cluster/show/#{@ems_cluster.id}?display=hosts#{breadcrumb_suffix}")
      @view, @pages = get_view(Host, :parent => @ems_cluster, :conditions => condition) # Get the records (into a view) and the paginator
      @showtype = "hosts"

    when "resource_pools"
      drop_breadcrumb(:name => @ems_cluster.name + _(" (All Resource Pools)"),
                      :url  => "/ems_cluster/show/#{@ems_cluster.id}?display=resource_pools")
      @view, @pages = get_view(ResourcePool, :parent => @ems_cluster) # Get the records (into a view) and the paginator
      @showtype = "resource_pools"

    when "config_info"
      @showtype = "config"
      drop_breadcrumb(:name => _("Configuration"), :url => "/ems_cluster/show/#{@ems_cluster.id}?display=#{@display}")

    when "performance"
      @showtype = "performance"
      drop_breadcrumb(:name => _("%{name} Capacity & Utilization") % {:name => @ems_cluster.name},
                      :url  => "/ems_cluster/show/#{@ems_cluster.id}?display=#{@display}&refresh=n")
      perf_gen_init_options               # Intialize perf chart options, charts will be generated async

    when "timeline"
      @showtype = "timeline"
      session[:tl_record_id] = params[:id] if params[:id]
      @record = find_by_id_filtered(EmsCluster, session[:tl_record_id])
      @timeline = @timeline_filter = true
      @lastaction = "show_timeline"
      tl_build_timeline                       # Create the timeline report
      drop_breadcrumb(:name => _("Timelines"), :url => "/ems_cluster/show/#{@record.id}?refresh=n&display=timeline")

    when "storage"
      drop_breadcrumb(:name => @ems_cluster.name + _(" (All Descendant %{table}(s))") %
        {:table => ui_lookup(:table => "storages")},
                      :url  => "/ems_cluster/show/#{@ems_cluster.id}?display=storage")
      @view, @pages = get_view(Storage, :parent => @ems_cluster)  # Get the records (into a view) and the paginator
      @showtype = "storage"

    when "storage_extents"
      drop_breadcrumb(:name => @ems_cluster.name + _(" (All %{tables})") %
        {:tables => ui_lookup(:tables => "cim_base_storage_extent")},
                      :url  => "/ems_cluster/show/#{@ems_cluster.id}?display=storage_extents")
      @view, @pages = get_view(CimBaseStorageExtent, :parent => @ems_cluster, :parent_method => :base_storage_extents)  # Get the records (into a view) and the paginator
      @showtype = "storage_extents"

    when "storage_systems"
      drop_breadcrumb(:name => @ems_cluster.name + _(" (All %{tables})") %
        {:tables => ui_lookup(:tables => "ontap_storage_system")},
                      :url  => "/ems_cluster/show/#{@ems_cluster.id}?display=storage_systems")
      @view, @pages = get_view(OntapStorageSystem, :parent => @ems_cluster, :parent_method => :storage_systems) # Get the records (into a view) and the paginator
      @showtype = "storage_systems"

    when "ontap_storage_volumes"
      drop_breadcrumb(:name => @ems_cluster.name + _(" (All %{tables})") %
        {:tables => ui_lookup(:tables => "ontap_storage_volume")},
                      :url  => "/ems_cluster/show/#{@ems_cluster.id}?display=ontap_storage_volumes")
      @view, @pages = get_view(OntapStorageVolume, :parent => @ems_cluster, :parent_method => :storage_volumes) # Get the records (into a view) and the paginator
      @showtype = "ontap_storage_volumes"

    when "ontap_file_shares"
      drop_breadcrumb(:name => @ems_cluster.name + _(" (All %{tables})") %
        {:tables => ui_lookup(:tables => "ontap_file_share")},
                      :url  => "/ems_cluster/show/#{@ems_cluster.id}?display=ontap_file_shares")
      @view, @pages = get_view(OntapFileShare, :parent => @ems_cluster, :parent_method => :file_shares) # Get the records (into a view) and the paginator
      @showtype = "ontap_file_shares"
    end

    set_config(@ems_cluster)
    session[:tl_record_id] = @record.id

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["all_vms", "vms", "hosts", "resource_pools"].include?(@display)  # Were we displaying sub-items

    if params[:pressed].starts_with?("vm_", # Handle buttons from sub-items screen
                                     "miq_template_",
                                     "guest_",
                                     "host_",
                                     "rp_")

      scanhosts if params[:pressed] == "host_scan"
      analyze_check_compliance_hosts if params[:pressed] == "host_analyze_check_compliance"
      check_compliance_hosts if params[:pressed] == "host_check_compliance"
      refreshhosts if params[:pressed] == "host_refresh"
      tag(Host) if params[:pressed] == "host_tag"
      assign_policies(Host) if params[:pressed] == "host_protect"
      comparemiq  if params[:pressed] == "host_compare"
      edit_record  if params[:pressed] == "host_edit"
      deletehosts if params[:pressed] == "host_delete"

      tag(ResourcePool) if params[:pressed] == "rp_tag"

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      # Handle Host power buttons
      if ["host_shutdown", "host_reboot", "host_standby", "host_enter_maint_mode", "host_exit_maint_mode",
          "host_start", "host_stop", "host_reset"].include?(params[:pressed])
        powerbutton_hosts(params[:pressed].split("_")[1..-1].join("_")) # Handle specific power button
      else
        process_vm_buttons(pfx)
        return if ["host_tag", "#{pfx}_policy_sim", "host_scan", "host_refresh", "host_protect",
                   "host_compare", "#{pfx}_compare", "#{pfx}_drift", "#{pfx}_tag", "#{pfx}_retire",
                   "#{pfx}_protect", "#{pfx}_ownership", "#{pfx}_right_size",
                   "#{pfx}_reconfigure", "rp_tag"].include?(params[:pressed]) &&
                  @flash_array.nil?   # Some other screen is showing, so return

        unless ["host_edit", "#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone", "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
          @refresh_div = "main_div"
          @refresh_partial = "layouts/gtl"
          show
        end
      end
    else
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      drift_analysis if params[:pressed] == "common_drift"
      tag(EmsCluster) if params[:pressed] == "ems_cluster_tag"
      scanclusters if params[:pressed] == "ems_cluster_scan"
      comparemiq if params[:pressed] == "ems_cluster_compare"
      deleteclusters if params[:pressed] == "ems_cluster_delete"
      assign_policies(EmsCluster) if params[:pressed] == "ems_cluster_protect"
      custom_buttons if params[:pressed] == "custom_button"
    end

    return if ["custom_button"].include?(params[:pressed])    # custom button screen, so return, let custom_buttons method handle everything
    return if ["ems_cluster_tag", "ems_cluster_compare", "common_drift", "ems_cluster_protect"].include?(params[:pressed]) && @flash_array.nil?   # Tag screen showing, so return

    if !@flash_array && !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    elsif @flash_array && @lastaction == "show"
      @ems_cluster = @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if !@flash_array.nil? && params[:pressed] == "ems_cluster_delete" && @single_delete
      javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message] # redirect to build the retire screen
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

  private ############################

  def hosts_subsets
    condition         = nil
    label             = _("%{name} (All %{titles})" % {:name => @ems_cluster.name, :titles => title_for_hosts})
    breadcrumb_suffix = ""

    host_service_group_name = params[:host_service_group_name]
    if host_service_group_name
      case params[:status]
      when 'running'
        hosts_filter =  @ems_cluster.host_ids_with_running_service_group(host_service_group_name)
        label        = _("Hosts with running %{name}") % {:name => host_service_group_name}
      when 'failed'
        hosts_filter =  @ems_cluster.host_ids_with_failed_service_group(host_service_group_name)
        label        = _("Hosts with failed %{name}") % {:name => host_service_group_name}
      when 'all'
        hosts_filter = @ems_cluster.host_ids_with_service_group(host_service_group_name)
        label        = _("All %{titles} with %{name}") % {:titles => title_for_hosts, :name => host_service_group_name}
      end

      if hosts_filter
        condition = ["hosts.id IN (#{hosts_filter.to_sql})"]
        breadcrumb_suffix = "&host_service_group_name=#{host_service_group_name}&status=#{params[:status]}"
      end
    end

    return label, condition, breadcrumb_suffix
  end

  def breadcrumb_name(_model)
    title_for_clusters
  end

  def set_config(db_record)
    @cluster_config = []
    @cluster_config.push(:field       => "HA Enabled",
                         :description => db_record.ha_enabled) unless db_record.ha_enabled.nil?
    @cluster_config.push(:field       => "HA Admit Control",
                         :description => db_record.ha_admit_control) unless db_record.ha_admit_control.nil?
    @cluster_config.push(:field       => "DRS Enabled",
                         :description => db_record.drs_enabled) unless db_record.drs_enabled.nil?
    @cluster_config.push(:field       => "DRS Automation Level",
                         :description => db_record.drs_automation_level) unless db_record.drs_automation_level.nil?
    @cluster_config.push(:field       => "DRS Migration Threshold",
                         :description => db_record.drs_migration_threshold) unless db_record.drs_migration_threshold.nil?
  end

  def get_session_data
    @title      = _("Clusters")
    @layout     = "ems_cluster"
    @lastaction = session[:ems_cluster_lastaction]
    @display    = session[:ems_cluster_display]
    @filters    = session[:ems_cluster_filters]
    @catinfo    = session[:ems_cluster_catinfo]
  end

  def set_session_data
    session[:ems_cluster_lastaction] = @lastaction
    session[:ems_cluster_display]    = @display unless @display.nil?
    session[:ems_cluster_filters]    = @filters
    session[:ems_cluster_catinfo]    = @catinfo
  end

  menu_section :inf
end
