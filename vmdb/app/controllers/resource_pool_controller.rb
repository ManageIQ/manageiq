class ResourcePoolController < ApplicationController

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @showtype   = "config"
    @record = identify_record(params[:id])
    return if record_no_longer_exists?(@record)

    @gtl_url = "/resource_pool/show/" << @record.id.to_s << "?"
    drop_breadcrumb( {:name=>"Resource Pools", :url=>"/resource_pool/show_list?page=#{@current_page}&refresh=y"}, true )

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@record)
      txt = @record.vapp ? " (vApp)" : ""
      drop_breadcrumb( {:name=>@record.name + txt + " (Summary)", :url=>"/resource_pool/show/#{@record.id}"} )
      @showtype = "main"
      set_summary_pdf_data if ["download_pdf","summary_only"].include?(@display)

    when "vms"
      drop_breadcrumb( {:name=>@record.name+" (Direct VMs)", :url=>"/resource_pool/show/#{@record.id}?display=vms"} )
      @view, @pages = get_view(Vm, :parent=>@record)  # Get the records (into a view) and the paginator
      @showtype = "vms"
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other VM") + " in this Resource Pool"
      end

    when "descendant_vms"
      drop_breadcrumb({:name=>@record.name+" (All VMs - Tree View)",
                      :url=>"/resource_pool/show/#{@record.id}?display=descendant_vms&treestate=true"})
      @showtype = "config"
      build_dc_tree

    when "all_vms"
      drop_breadcrumb( {:name=>@record.name+" (All VMs)", :url=>"/resource_pool/show/#{@record.id}?display=all_vms"} )
      @view, @pages = get_view(Vm, :parent=>@record, :association=>"all_vms") # Get the records (into a view) and the paginator
      @showtype = "vms"
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
          @view.extras[:total_count] > @view.extras[:auth_count]
        @bottom_msg = "* You are not authorized to view " + pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other VM") + " in this Resource Pool"
      end

    when "clusters"
      drop_breadcrumb( {:name=>@record.name+" (All Clusters)", :url=>"/resource_pool/show/#{@record.id}?display=clusters"} )
      @view, @pages = get_view(EmsCluster, :parent=>@record)  # Get the records (into a view) and the paginator
      @showtype = "clusters"

    when "resource_pools"
      drop_breadcrumb( {:name=>@record.name+" (All Resource Pools)", :url=>"/resource_pool/show/#{@record.id}?display=resource_pools"} )
      @view, @pages = get_view(ResourcePool, :parent=>@record)  # Get the records (into a view) and the paginator
      @showtype = "resource_pools"

    when"config_info"
      @showtype = "config"
      drop_breadcrumb( {:name=>"Configuration", :url=>"/resource_pool/show/#{@record.id}?display=#{@display}"} )
    end

    set_config(@record)

    # Came in from outside show_list partial
    if params[:ppsetting]  || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def set_config(db_record)
    @rp_config = Array.new
    @rp_config.push({ :field => "Memory Reserve",
                              :description => db_record.memory_reserve
                            }) unless db_record.memory_reserve.nil?
    @rp_config.push({ :field => "Memory Reserve Expand",
                              :description => db_record.memory_reserve_expand
                            }) unless db_record.memory_reserve_expand.nil?
    if !db_record.memory_limit.nil?
      mem_limit = db_record.memory_limit
      mem_limit = "Unlimited" if db_record.memory_limit == -1
      @rp_config.push({ :field => "Memory Limit",
                              :description => mem_limit
                            })
    end
    @rp_config.push({ :field => "Memory Shares",
                              :description => db_record.memory_shares
                            }) unless db_record.memory_shares.nil?
    @rp_config.push({ :field => "Memory Shares Level",
                              :description => db_record.memory_shares_level
                            }) unless db_record.memory_shares_level.nil?
    @rp_config.push({ :field => "CPU Reserve",
                              :description => db_record.cpu_reserve
                            }) unless db_record.cpu_reserve.nil?
    @rp_config.push({ :field => "CPU Reserve Expand",
                              :description => db_record.cpu_reserve_expand
                            }) unless db_record.cpu_reserve_expand.nil?
    if !db_record.cpu_limit.nil?
      cpu_limit = db_record.cpu_limit
      cpu_limit = "Unlimited" if db_record.cpu_limit == -1
      @rp_config.push({ :field => "CPU Limit",
                              :description => cpu_limit
                            })
    end
    @rp_config.push({ :field => "CPU Shares",
                              :description => db_record.cpu_shares
                            }) unless db_record.cpu_shares.nil?
    @rp_config.push({ :field => "CPU Shares Level",
                              :description => db_record.cpu_shares_level
                            }) unless db_record.cpu_shares_level.nil?
  end

  def show_list
    process_show_list
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if ["all_vms","vms","resource_pools"].include?(@display)  # Were we displaying sub-items
    if ["all_vms","vms","resource_pools"].include?(@display)                  # Need to check, since RPs contain RPs

      if params[:pressed].starts_with?("vm_") ||      # Handle buttons from sub-items screen
          params[:pressed].starts_with?("miq_template_") ||
          params[:pressed].starts_with?("guest_")

        pfx = pfx_for_vm_button_pressed(params[:pressed])
        process_vm_buttons(pfx)

        return if ["#{pfx}_policy_sim","#{pfx}_compare","#{pfx}_tag","#{pfx}_protect",
                   "#{pfx}_retire","#{pfx}_right_size","#{pfx}_ownership",
                   "#{pfx}_reconfigure"].include?(params[:pressed]) &&
                  @flash_array == nil   # Some other screen is showing, so return

        if !["#{pfx}_edit","#{pfx}_miq_request_new","#{pfx}_clone",
             "#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
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

    return if ["resource_pool_tag","resource_pool_protect"].include?(params[:pressed]) && @flash_array == nil   # Tag screen showing, so return

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
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg=>@flash_array[0][:message]  # redirect to build the retire screen
      end
    elsif ["#{pfx}_miq_request_new","#{pfx}_migrate","#{pfx}_clone",
           "#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
      if @redirect_controller
        if ["#{pfx}_clone","#{pfx}_migrate","#{pfx}_migrate","#{pfx}_publish"].include?(params[:pressed])
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id, :prov_type=>@prov_type, :prov_id=>@prov_id
          end
        else
          render :update do |page|
            page.redirect_to :controller=>@redirect_controller, :action=>@refresh_partial, :id=>@redirect_id
          end
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
              if ["vms","hosts","resource_pools"].include?(@display)  # If displaying sub-items, action_url s/b show
                page << "miqReinitToolbar('center_tb');"
                page.replace_html("main_div", :partial=>"layouts/gtl", :locals=>{:action_url=>"show/#{@record.id}"})
              else
                page.replace_html("main_div", :partial=>@refresh_partial)
              end
            end
          end
        end
      end
    end
  end

  private ############################

  # Build the tree object to display the resource_pool datacenter info
  def build_dc_tree
      @sb[:tree_hosts] = Array.new                    # Capture all Host ids in the tree
      @sb[:tree_vms]   = Array.new                    # Capture all VM ids in the tree
      @sb[:rp_id] = @record.id if @record                 # do not want to store ems object in session hash, need to get record incase coming from treesize to rebuild refreshed tree
      if !@record
        @record = ResourcePool.find(@sb[:rp_id])
      end
      rp_node = TreeNodeBuilder.generic_tree_node(
        "resource_pool-#{to_cid(@record.id)}",
        @record.name,
        @record.vapp ? "vapp.png" : "resource_pool.png",
        "Resource Pool: #{@record.name}",
        :cfme_no_click => true,
        :expand        => true,
        :style_class   => "cfme-no-cursor-node"
      )
      rp_kids = []
      @sb[:vat] = false if params[:action] != "treesize"        #need to set this, to remember vat, treesize doesnt pass in param[:vat]
      vat = params[:vat] ? true : (@sb[:vat] ? true : false)    #use @sb[:vat] when coming from treesize
      @sb[:open_tree_nodes] = Array.new if params[:action] != "treesize"
      @record.resource_pools.each do |rp|   # Get the resource pool nodes
        rp_kids += get_dc_node(rp, rp_node[:key], vat)
      end
      @record.vms.each do |v|               # Get VMs
        rp_kids += get_dc_node(v, rp_node[:key], vat)
      end
      rp_node[:children] = rp_kids unless rp_kids.empty?

      session[:dc_tree]    = [rp_node].to_json
      session[:tree]       = "dc"
      session[:tree_name]  = "rp_dc_tree"
  end

  # Add the children of a node that is being expanded (autoloaded)
  def tree_add_child_nodes(id)
    return t_node = get_dc_child_nodes(id)
  end

  def get_session_data
    @title        = "Resource Pools"
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
end
