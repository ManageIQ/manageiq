class OrchestrationStackController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::CloudManager::OrchestrationStack
  end

  def self.table_name
    @table_name ||= "orchestration_stack"
  end

  def index
    redirect_to :action => 'show_list'
  end

  def show
    return if perfmenu_click?
    @display = params[:display] || "main" unless control_selected?

    @lastaction = "show"
    @orchestration_stack = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@orchestration_stack)

    @gtl_url = "/show"
    drop_breadcrumb({:name => _("Orchestration Stacks"),
                     :url  => "/orchestration_stack/show_list?page=#{@current_page}&refresh=y"}, true)
    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@orchestration_stack)
      drop_breadcrumb(:name => _("%{name} (Summary)") % {:name => @orchestration_stack.name},
                      :url  => "/orchestration_stack/show/#{@orchestration_stack.id}")
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    when "instances"
      title = ui_lookup(:tables => "vm_cloud")
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @orchestration_stack.name, :title => title},
                      :url  => "/orchestration_stack/show/#{@orchestration_stack.id}?display=#{@display}")
      @view, @pages = get_view(ManageIQ::Providers::CloudManager::Vm, :parent => @orchestration_stack)
      @showtype = @display
    when "children"
      title = ui_lookup(:tables => "orchestration_stack")
      kls   = OrchestrationStack
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @orchestration_stack.name, :title => title},
                      :url  => "/orchestration_stack/show/#{@orchestration_stack.id}?display=#{@display}")
      @view, @pages = get_view(kls, :parent => @orchestration_stack)
      @showtype = @display
    when "security_groups"
      title = ui_lookup(:tables => "security_group")
      kls   = SecurityGroup
      drop_breadcrumb(:name => _("%{name} (All %{title})") % {:name => @orchestration_stack.name, :title => title},
                      :url  => "/orchestration_stack/show/#{@orchestration_stack.id}?display=#{@display}")
      @view, @pages = get_view(kls, :parent => @orchestration_stack)  # Get the records (into a view) and the paginator
      @showtype = @display
    when "stack_orchestration_template"
      drop_breadcrumb(:name => "%{name} (Orchestration Template)" % {:name => @orchestration_stack.name},
                      :url  => "/orchestration_stack/show/#{@orchestration_stack.id}?display=#{@display}")
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
    show_association('cloud_networks', _('Cloud Networks'), 'cloud_network', :cloud_networks, CloudNetwork)
  end

  def outputs
    show_association('outputs', _('Outputs'), 'output', :outputs, OrchestrationStackOutput)
  end

  def parameters
    show_association('parameters', _('Parameters'), 'parameter', :parameters, OrchestrationStackParameter)
  end

  def resources
    show_association('resources', _('Resources'), 'resource', :resources, OrchestrationStackResource)
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
    elsif params[:pressed] == "make_ot_orderable"
      make_ot_orderable
      return
    elsif params[:pressed] == "orchestration_template_copy"
      orchestration_template_copy
      return
    elsif params[:pressed] == "orchestration_templates_view"
      orchestration_templates_view
      return
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
      javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message]
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

  def stacks_ot_info
    ot = find_by_id_filtered(OrchestrationStack, params[:id]).orchestration_template
    render :json => {
      :template_id          => ot.id,
      :template_name        => ot.name,
      :template_description => ot.description,
      :template_draft       => ot.draft,
      :template_content     => ot.content
    }
  end

  def stacks_ot_copy
    case params[:button]
    when "cancel"
      stacks_ot_copy_cancel
    when "add"
      stacks_ot_copy_submit
    end
  end

  private ############################

  def make_ot_orderable
    stack = find_by_id_filtered(OrchestrationStack, params[:id])
    template = stack.orchestration_template
    if template.orderable?
      add_flash(_("Orchestration template \"%{name}\" is already orderable") % {:name => template.name}, :error)
      render_flash
    else
      begin
        template.save_as_orderable!
      rescue => bang
        add_flash(_("An error occured when changing orchestration template \"%{name}\" to orderable: %{err_msg}") %
          {:name => template.name, :err_msg => bang.message}, :error)
        render_flash
      else
        @record = stack
        add_flash(_("Orchestration template \"%{name}\" is now orderable") % {:name => template.name})
        render :update do |page|
          page << javascript_prologue
          page.replace(:form_div, :partial => "stack_orchestration_template")
          page << javascript_pf_toolbar_reload('center_tb', build_toolbar(center_toolbar_filename))
          page << javascript_show_if_exists(:toolbar)
        end
      end
    end
  end

  def orchestration_template_copy
    @record = find_by_id_filtered(OrchestrationStack, params[:id])
    if @record.orchestration_template.orderable?
      add_flash(_("Orchestration template \"%{name}\" is already orderable") %
        {:name => @record.orchestration_template.name}, :error)
      render_flash
    else
      render :update do |page|
        page << javascript_prologue
        page.replace(:form_div, :partial => "copy_orchestration_template")
        page << javascript_hide_if_exists(:toolbar)
      end
    end
  end

  def stacks_ot_copy_cancel
    @record = find_by_id_filtered(OrchestrationStack, params[:id])
    add_flash(_("Copy of Orchestration Template was cancelled by the user"))
    render :update do |page|
      page << javascript_prologue
      page.replace(:form_div, :partial => "stack_orchestration_template")
      page << javascript_show_if_exists(:toolbar)
    end
  end

  def stacks_ot_copy_submit
    assert_privileges('orchestration_template_copy')
    original_template = find_by_id_filtered(OrchestrationTemplate, params[:templateId])
    if params[:templateContent] == original_template.content
      add_flash(_("Unable to create a new template copy \"%{name}\": old and new template content have to differ.") %
        {:name => params[:templateName]})
      render_flash
    elsif params[:templateContent].nil? || params[:templateContent] == ""
      add_flash(_("Unable to create a new template copy \"%{name}\": new template content cannot be empty.") %
        {:name => params[:templateName]})
      render_flash
    else
      ot = OrchestrationTemplate.new(
        :name        => params[:templateName],
        :description => params[:templateDescription],
        :type        => original_template.type,
        :content     => params[:templateContent],
        :draft       => params[:templateDraft] == "true",
      )
      begin
        ot.save_as_orderable!
      rescue => bang
        add_flash(_("Error during 'Orchestration Template Copy': %{error_message}") %
          {:error_message => bang.message}, :error)
        render_flash
      else
        flash_message = _("%{model} \"%{name}\" was saved") % {:model => ui_lookup(:model => 'OrchestrationTemplate'),
                                                               :name  => ot.name}
        javascript_redirect :controller    => 'catalog',
                            :action        => 'ot_show',
                            :id            => ot.id,
                            :flash_message => flash_message
      end
    end
  end

  def orchestration_templates_view
    template = find_by_id_filtered(OrchestrationStack, params[:id]).orchestration_template
    javascript_redirect :controller => 'catalog', :action => 'ot_show', :id => template.id
  end

  def get_session_data
    @title      = _("Stack")
    @layout     = "orchestration_stack"
    @lastaction = session[:orchestration_stack_lastaction]
    @display    = session[:orchestration_stack_display]
  end

  def set_session_data
    session[:orchestration_stack_lastaction] = @lastaction
    session[:orchestration_stack_display]    = @display unless @display.nil?
  end

  menu_section :clo
end
