class ResourcePoolController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype   = "config"
    @record = identify_record(params[:id])
    return if record_no_longer_exists?(@record)

    @gtl_url = "/show"
    drop_breadcrumb({:name => _("Resource Pools"),
                     :url  => "/resource_pool/show_list?page=#{@current_page}&refresh=y"}, true)

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@record)
      txt = @record.vapp ? _("(vApp)") : ""
      drop_breadcrumb(:name => _("%{name} %{text} (Summary)") % {:name => @record.name, :text => txt},
                      :url  => "/resource_pool/show/#{@record.id}")
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf", "summary_only"].include?(@display)

    when "vms"
      drop_breadcrumb(:name => _("%{name} (Direct VMs)") % {:name => @record.name},
                      :url  => "/resource_pool/show/#{@record.id}?display=vms")
      @view, @pages = get_view(Vm, :parent => @record)  # Get the records (into a view) and the paginator
      @showtype = "vms"

    when "descendant_vms"
      drop_breadcrumb(:name => _("%{name} (All VMs - Tree View)") % {:name => @record.name},
                      :url  => "/resource_pool/show/#{@record.id}?display=descendant_vms&treestate=true")
      @showtype = "config"

      self.x_active_tree = :datacenter_tree
      cluster = @record
      @datacenter_tree = TreeBuilderDatacenter.new(:datacenter_tree, :datacenter, @sb, true, cluster)

    when "all_vms"
      drop_breadcrumb(:name => "%{name} (All VMs)" % {:name => @record.name},
                      :url  => "/resource_pool/show/#{@record.id}?display=all_vms")
      @view, @pages = get_view(Vm, :parent => @record, :association => "all_vms") # Get the records (into a view) and the paginator
      @showtype = "vms"

    when "clusters"
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @record.name, :title => title_for_clusters},
                      :url  => "/resource_pool/show/#{@record.id}?display=clusters")
      @view, @pages = get_view(EmsCluster, :parent => @record)  # Get the records (into a view) and the paginator
      @showtype = "clusters"

    when "resource_pools"
      drop_breadcrumb(:name => _("%{name} (All Resource Pools)") % {:name => @record.name},
                      :url  => "/resource_pool/show/#{@record.id}?display=resource_pools")
      @view, @pages = get_view(ResourcePool, :parent => @record)  # Get the records (into a view) and the paginator
      @showtype = "resource_pools"

    when"config_info"
      @showtype = "config"
      drop_breadcrumb(:name => _("Configuration"), :url => "/resource_pool/show/#{@record.id}?display=#{@display}")
    end

    set_config(@record)

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def set_config(db_record)
    @rp_config = []
    @rp_config.push(:field       => "Memory Reserve",
                    :description => db_record.memory_reserve) unless db_record.memory_reserve.nil?
    @rp_config.push(:field       => "Memory Reserve Expand",
                    :description => db_record.memory_reserve_expand) unless db_record.memory_reserve_expand.nil?
    unless db_record.memory_limit.nil?
      mem_limit = db_record.memory_limit
      mem_limit = "Unlimited" if db_record.memory_limit == -1
      @rp_config.push(:field       => "Memory Limit",
                      :description => mem_limit)
    end
    @rp_config.push(:field       => "Memory Shares",
                    :description => db_record.memory_shares) unless db_record.memory_shares.nil?
    @rp_config.push(:field       => "Memory Shares Level",
                    :description => db_record.memory_shares_level) unless db_record.memory_shares_level.nil?
    @rp_config.push(:field       => "CPU Reserve",
                    :description => db_record.cpu_reserve) unless db_record.cpu_reserve.nil?
    @rp_config.push(:field       => "CPU Reserve Expand",
                    :description => db_record.cpu_reserve_expand) unless db_record.cpu_reserve_expand.nil?
    unless db_record.cpu_limit.nil?
      cpu_limit = db_record.cpu_limit
      cpu_limit = "Unlimited" if db_record.cpu_limit == -1
      @rp_config.push(:field       => "CPU Limit",
                      :description => cpu_limit)
    end
    @rp_config.push(:field       => "CPU Shares",
                    :description => db_record.cpu_shares) unless db_record.cpu_shares.nil?
    @rp_config.push(:field       => "CPU Shares Level",
                    :description => db_record.cpu_shares_level) unless db_record.cpu_shares_level.nil?
  end

  def show_list
    process_show_list
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["all_vms", "vms", "resource_pools"].include?(@display)  # Were we displaying sub-items
    if ["all_vms", "vms", "resource_pools"].include?(@display)                  # Need to check, since RPs contain RPs

      if params[:pressed].starts_with?("vm_", # Handle buttons from sub-items screen
                                       "miq_template_",
                                       "guest_")

        pfx = pfx_for_vm_button_pressed(params[:pressed])
        process_vm_buttons(pfx)

        return if ["#{pfx}_policy_sim", "#{pfx}_compare", "#{pfx}_tag", "#{pfx}_protect",
                   "#{pfx}_retire", "#{pfx}_right_size", "#{pfx}_ownership",
                   "#{pfx}_reconfigure"].include?(params[:pressed]) &&
                  @flash_array.nil?   # Some other screen is showing, so return

        unless ["#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone",
                "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
          @refresh_div = "main_div"
          @refresh_partial = "layouts/gtl"
          show
        end
      end
    else
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      tag(ResourcePool) if params[:pressed] == "resource_pool_tag"
      deleteresourcepools if params[:pressed] == "resource_pool_delete"
      assign_policies(ResourcePool) if params[:pressed] == "resource_pool_protect"
    end

    return if ["resource_pool_tag", "resource_pool_protect"].include?(params[:pressed]) && @flash_array.nil?   # Tag screen showing, so return

    if !@flash_array && !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div     = "flash_msg_div"
    elsif @flash_array && @lastaction == "show"
      @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div     = "flash_msg_div"
    end

    if !@flash_array.nil? && params[:pressed] == "resource_pool_delete" && @single_delete
      javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message] # redirect to build the retire screen
    elsif ["#{pfx}_miq_request_new", "#{pfx}_migrate", "#{pfx}_clone",
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

  def get_session_data
    @title        = _("Resource Pools")
    @layout       = "resource_pool"
    @display      = session[:resource_pool_display]
    @filters      = session[:resource_pool_filters]
    @catinfo      = session[:resource_pool_catinfo]
    @current_page = session[:resource_pool_current_page]
    @search_text  = session[:resource_pool_search_text]
    @lastaction   = session[:rp_lastaction]
  end

  def set_session_data
    session[:resource_pool_lastaction]   = @lastaction
    session[:resource_pool_display]      = @display || session[:resource_pool_display]
    session[:resource_pool_filters]      = @filters
    session[:resource_pool_catinfo]      = @catinfo
    session[:resource_pool_current_page] = @current_page
    session[:resource_pool_search_text]  = @search_text
    session[:rp_lastaction]              = @lastaction
  end

  menu_section :inf
end
