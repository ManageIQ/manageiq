class OrchestrationStackController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def show
    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @orchestration_stack = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@orchestration_stack)

    @gtl_url = "/orchestration_stack/show/" << @orchestration_stack.id.to_s << "?"
    drop_breadcrumb({:name => "Orchestration Stacks",
                     :url  => "/orchestration_stack/show_list?page=#{@current_page}&refresh=y"}, true)
    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@orchestration_stack)
      drop_breadcrumb(:name => "#{@orchestration_stack.name} (Summary)",
                      :url  => "/orchestration_stack/show/#{@orchestration_stack.id}")
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    when "instances"
      title = ui_lookup(:tables => "vm_cloud")
      drop_breadcrumb(:name => "#{@orchestration_stack.name} (All #{title})",
                      :url  => "/orchestration_stack/show/#{@orchestration_stack.id}?display=#{@display}")
      @view, @pages = get_view(ManageIQ::Providers::CloudManager::Vm, :parent => @orchestration_stack)
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
         @view.extras[:total_count] > @view.extras[:auth_count]
        count_text = pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}")
        @bottom_msg = "* You are not authorized to view #{count_text} on this #{ui_lookup(:tables => 'orchestration_stack')}"
      end
    when "security_groups"
      table = "security_groups"
      title = ui_lookup(:tables => table)
      kls   = SecurityGroup
      drop_breadcrumb(:name => "#{@orchestration_stack.name} (All #{title})",
                      :url  => "/orchestration_stack/show/#{@orchestration_stack.id}?display=#{@display}")
      @view, @pages = get_view(kls, :parent => @orchestration_stack)  # Get the records (into a view) and the paginator
      @showtype = @display
      if @view.extras[:total_count] && @view.extras[:auth_count] &&
         @view.extras[:total_count] > @view.extras[:auth_count]
        count_text = pluralize(@view.extras[:total_count] - @view.extras[:auth_count], "other #{title.singularize}")
        @bottom_msg = "* You are not authorized to view #{count_text} on this #{ui_lookup(:tables => 'orchestration_stack')}"
      end
    end

    # Came in from outside show_list partial
    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  def show_list
    process_show_list
  end

  def cloud_networks
    show_association('cloud_networks', 'Cloud Networks', 'cloud_network', :cloud_networks, CloudNetwork)
  end

  def outputs
    show_association('outputs', 'Outputs', 'output', :outputs, OrchestrationStackOutput)
  end

  def parameters
    show_association('parameters', 'Parameters', 'parameter', :parameters, OrchestrationStackParameter)
  end

  def resources
    show_association('resources', 'Resources', 'resource', :resources, OrchestrationStackResource)
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                          # Restore @edit for adv search box

    params[:display] = @display if ["instances"].include?(@display)  # Were we displaying vms/hosts/storages
    params[:page] = @current_page if @current_page.nil?   # Save current page for list refresh

    if params[:pressed].starts_with?("instance_")        # Handle buttons from sub-items screen
      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)

      # Control transferred to another screen, so return
      return if ["#{pfx}_policy_sim", "#{pfx}_compare", "#{pfx}_tag",
                 "#{pfx}_retire", "#{pfx}_protect", "#{pfx}_ownership",
                 "#{pfx}_refresh", "#{pfx}_right_size",
                 "#{pfx}_reconfigure"].include?(params[:pressed]) &&
                @flash_array.nil?

      unless ["#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone",
              "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show                                                        # Handle VMs buttons
      end
    else
      params[:page] = @current_page if @current_page.nil?                     # Save current page for list refresh
      @refresh_div = "main_div" # Default div for button.rjs to refresh
      case params[:pressed]
      when "orchestration_stack_delete"
        orchestration_stack_delete
      when "orchestration_stack_retire"
        orchestration_stack_retire
      when "orchestration_stack_retire_now"
        orchestration_stack_retire_now
      when "orchestration_stack_tag"
        tag(OrchestrationStack)
      end
      return if %w(orchestration_stack_retire orchestration_stack_tag).include?(params[:pressed]) &&
                @flash_array.nil? # Tag screen showing, so return
    end

    if @flash_array.nil? && !@refresh_partial # if no button handler ran, show not implemented msg
      add_flash(_("Button not yet implemented"), :error)
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    elsif @flash_array && @lastaction == "show"
      @orchestration_stack = @record = identify_record(params[:id])
      @refresh_partial = "layouts/flash_msg"
      @refresh_div = "flash_msg_div"
    end

    if !@flash_array.nil? && params[:pressed] == "orchestration_stack_delete" && @single_delete
      render :update do |page|
        page.redirect_to :action => 'show_list', :flash_msg => @flash_array[0][:message]
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

  private ############################

  def get_session_data
    @title      = "Stack"
    @layout     = "orchestration_stack"
    @lastaction = session[:orchestration_stack_lastaction]
    @display    = session[:orchestration_stack_display]
  end

  def set_session_data
    session[:orchestration_stack_lastaction] = @lastaction
    session[:orchestration_stack_display]    = @display unless @display.nil?
  end
end
