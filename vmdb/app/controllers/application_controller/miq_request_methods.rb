module ApplicationController::MiqRequestMethods
  extend ActiveSupport::Concern
  included do
    helper_method :dialog_partial_for_workflow
  end

  # AJAX driven routine to check for changes on the provision form
  def prov_field_changed
    if params[:tab_id]
      @edit = session[:edit]
    else
      return unless load_edit("prov_edit__#{params[:id]}","show_list")
    end
    if @edit.nil? || @edit.try(:[], :stamp_typ)  # load tab for show screen
      if params[:tab_id]
        @options[:current_tab_key] = params[:tab_id].split('_')[0].to_sym
        @options[:wf].refresh_field_values(@options,session[:userid])
      end
      prov_load_tab
    else
      if params[:tab_id]
        @edit[:new][:current_tab_key] = params[:tab_id].split('_')[0].to_sym
        @edit[:wf].refresh_field_values(@edit[:new],session[:userid])
      end
      refresh_divs = prov_get_form_vars  # Get changed option, returns true if divs need refreshing
      build_grid if refresh_divs
      changed = (@edit[:new] != @edit[:current])
      render :update do |page|                    # Use JS to update the display
        #Going thru all dialogs to see if model has set any of the dialog display to hide/ignore
        all_dialogs = @edit[:wf].get_all_dialogs
        all_dialogs.each do |dialog_name, dialog|
          page << "li_id = '#{dialog_name}_li';"
          page << "miq_jquery_show_hide_tab(li_id, #{dialog[:display] == :show ? "'show'" : "'hide'"});"
        end
        if refresh_divs
          all_dialogs.each do |dialog_name, dialog|
            if dialog[:display] == :show && dialog_name == @edit[:new][:current_tab_key]
              page.replace_html("#{dialog_name}_div", :partial => dialog_partial_for_workflow, :locals => {:wf => @edit[:wf], :dialog => dialog_name})
            end
          end
        end
        if @edit.fetch_path(:new, :schedule_type, 0) == "schedule"
          page << "miq_cal_dateFrom = new Date(#{@timezone_offset});"
          page << "miqBuildCalendar();"
        end
        if changed != session[:changed]
          session[:changed] = changed
          page << javascript_for_miq_button_visibility(changed)
        end
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
        page << "miqSparkle(false);"
      end
    end
  end

  def pre_prov_continue
    if params[:button] == "submit"
      prov_edit
    else
      pre_prov
    end
  end

  # Pre provisioning, select a template
  def pre_prov
    if params[:button] == "cancel"
      add_flash(_("Add of new %s was cancelled by the user") % "#{session[:edit][:prov_type]} Request")
      session[:flash_msgs] = @flash_array.dup unless session[:edit][:explorer]  # Put msg in session for next transaction to display
      @explorer = session[:edit][:explorer] ? session[:edit][:explorer] : false
      @edit = session[:edit] =  nil                                               # Clear out session[:edit]
      if @explorer
        @sb[:action] = nil
        replace_right_cell
      else
        render :update do |page|
          if @breadcrumbs && (@breadcrumbs.empty? || @breadcrumbs.last[:url] == "/vm/show_list")
            page.redirect_to :action =>"show_list", :controller=>"vm"
          else
            #had to get id from breadcrumbs url, because there is no params[:id] when cancel is pressed on copy Request screen.
            url = @breadcrumbs.last[:url].split('/')
            page.redirect_to :controller=>url[1], :action =>url[2], :id=>url[3]
          end
        end
      end
    elsif params[:button] == "continue"       # Template chosen, start vm provisioning
      params[:button] = nil                   # Clear the incoming button
      @edit = session[:edit]                  # Grab what we need from @edit
      @explorer = @edit[:explorer]

      if @edit[:wf].nil?
        @src_vm_id = @edit[:src_vm_id]          # Hang on to selected VM to populate prov
        @edit = session[:edit] = nil
      else
        @workflow_exists = true
        @src_vm_id = @edit[:wf].last_vm_id
        validate_preprov
      end
      if @flash_array
        render :update do |page|                    # Use JS to update the display
          page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        end
      else
        @redirect_controller = "miq_request"
        @refresh_partial = "miq_request/prov_edit"
        if @explorer
          @_params[:org_controller] = "vm"        # Set up for prov_edit
          prov_edit
          @sb[:action] = "pre_prov"
          replace_right_cell
        else
          render :update do |page|
            page.redirect_to :controller     => @redirect_controller,
                             :action         => "prov_edit",
                             :src_vm_id      => @src_vm_id,
                             :org_controller => "vm"
            page.replace("flash_msg_div", :partial => "layouts/flash_msg")
          end
        end
      end
    elsif params[:sort_choice]
      @edit = session[:edit]
      if @edit[:vm_sortcol] == params[:sort_choice]                       # if same column was selected
        @edit[:vm_sortdir] = @edit[:vm_sortdir] == "ASC" ? "DESC" : "ASC"     #   switch around ascending/descending
      else
        @edit[:vm_sortdir] = "ASC"
      end
      @edit[:vm_sortcol] = params[:sort_choice]
      templates = rbac_filtered_objects(@edit[:template_kls].eligible_for_provisioning).sort_by {|a| a.name.downcase}
      self.send("build_vm_grid", templates, @edit[:vm_sortdir], @edit[:vm_sortcol])
      render :update do |page|                        # Use RJS to update the display
        page.replace("pre_prov_div", :partial=>"miq_request/pre_prov")
        page << "miqSparkle(false);"
      end
    elsif params[:sel_id]
      @edit = session[:edit]
      render :update do |page|                        # Use RJS to update the display
        page << "$('#row_#{j_str(@edit[:src_vm_id])}').removeClass('selected');" if @edit[:src_vm_id]
        page << "$('#row_#{j_str(params[:sel_id])}').addClass('selected');"
        session[:changed] = true
        page << javascript_for_miq_button_visibility(session[:changed])
        @edit[:src_vm_id] = params[:sel_id].to_i
      end
    else                                                        # First time in, build pre-provision screen
      @layout = "miq_request_vm"
      @edit = Hash.new
      @edit[:explorer] = @explorer
      @edit[:vm_sortdir] ||= "ASC"
      @edit[:vm_sortcol] ||= "name"
      @edit[:prov_type] = "VM Provision"
      @edit[:template_kls] = get_template_kls
      templates = rbac_filtered_objects(@edit[:template_kls].eligible_for_provisioning).sort_by {|a| a.name.downcase}
      build_vm_grid(templates, @edit[:vm_sortdir],@edit[:vm_sortcol])
      session[:changed] = false                                 # Turn off the submit button
      @edit[:explorer] = true if @explorer
      @in_a_form = true
    end
  end
  alias instance_pre_prov pre_prov
  alias vm_pre_prov pre_prov

  def get_template_kls
    # when clone/migrate buttons are pressed from a sub list view,
    # these buttons are only available on Infra side
    return TemplateInfra if params[:prov_type]
    case request.parameters[:controller]
      when "vm_cloud"
        return TemplateCloud
      when "vm_infra"
        return TemplateInfra
      else
        return MiqTemplate
    end
  end

  # Add/edit a provision request
  def prov_edit
    if params[:button] == "cancel"
      req = MiqRequest.find_by_id(from_cid(session[:edit][:req_id])) if session[:edit] && session[:edit][:req_id]
      add_flash(req && req.id ? _("Edit of %{model} \"%{name}\" was cancelled by the user") % {:model=>"#{session[:edit][:prov_type]} Request", :name=>req.description} : _("Provision %s was cancelled by the user") % "#{session[:edit][:prov_type]} Request")
      session[:flash_msgs] = @flash_array.dup unless session[:edit][:explorer]  # Put msg in session for next transaction to display
      @explorer = session[:edit][:explorer] ? session[:edit][:explorer] : false
      @edit = session[:edit] =  nil                                               # Clear out session[:edit]
      @breadcrumbs.pop if @breadcrumbs
      prov_request_cancel_submit_response
    elsif params[:button] == "submit"                           # Update or create the request from the workflow with the new options
      prov_req_submit
    else                                                        # First time in, build provision request screen
      @layout = layout_from_tab_name(params[:org_controller])
      if params[:commit] == "Upload" && session.fetch_path(:edit, :new, :sysprep_enabled, 1) == "Sysprep Answer File"
        upload_sysprep_file
        @tabactive = "customize_div"
      else
        if params[:req_id]
          prov_set_form_vars(MiqRequest.find(params[:req_id]))    # Set vars from existing request
          session[:changed] = false                               # Turn off the submit button
        else
          prov_set_form_vars                                      # Set default vars
          session[:changed] = true                                # Turn on the submit button
        end
        @edit[:explorer] = true if @explorer
        @tabactive = "#{@edit[:new][:current_tab_key]}_div"
      end
      drop_breadcrumb( {:name=>"#{params[:req_id] ? "Edit" : "Add"} #{@edit[:prov_type]} Request", :url=>"/vm/provision"} )
      @in_a_form = true
#     render :action=>"show"
    end
  end

  # get the sort column that was clicked on, else use the current one
  def sort_ds_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    field = ["miq_template","vm","service_template"].include?(@edit[:org_controller]) ? :placement_ds_name : :attached_ds
    sort_grid('ds', @edit[:wf].get_field(field,:environment)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_vm_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    sort_grid('vm', @edit[:wf].get_field(:src_vm_id,:service)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_host_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    @edit[:wf].kind_of?(MiqHostProvisionWorkflow) ? sort_grid('host', @edit[:wf].get_field(:src_host_ids, :service)[:values]) : sort_grid('host', @edit[:wf].get_field(:placement_host_name, :environment)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_configured_system_grid
    return unless load_edit("prov_edit__#{params[:id]}", "show_list")
    sort_grid('configured_system', @edit[:wf].get_field(:src_configured_system_ids, :service)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_pxe_img_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    sort_grid('pxe_img', @edit[:wf].get_field(:pxe_image_id,:service)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_iso_img_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    sort_grid('iso_img', @edit[:wf].get_field(:iso_image_id,:service)[:values])
  end

  def sort_windows_image_grid
    return unless load_edit("prov_edit__#{params[:id]}","show_list")
    sort_grid('windows_image', @edit[:wf].get_field(:windows_image_id,:service)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_vc_grid
    @edit = session[:edit]
    sort_grid('vc', @edit[:wf].get_field(:sysprep_custom_spec,:customize)[:values])
  end

  # get the sort column that was clicked on, else use the current one
  def sort_template_grid
    @edit = session[:edit]
    sort_grid('script', @edit[:wf].get_field(:customization_template_id,:customize)[:values])
  end

  private ############################

  def _build_whatever_grid(what, list, headers, sort_order, sort_by, integer_fields = [], state = @edit)
    state["#{what}_headers".to_sym] = headers
    state["#{what}_columns".to_sym] = headers.keys
    state["#{what}_sortcol".to_sym] = sort_by
    state["#{what}_sortdir".to_sym] = sort_order

    post_sort_method = integer_fields.include?(sort_by) ? :to_i : :downcase
    sorted = list.sort_by { |item| item.deep_send(sort_by).to_s.send(post_sort_method) }.uniq
    (sort_order == "ASC") ? sorted : sorted.reverse
  end

  def build_configured_system_grid(configured_systems, sort_order = nil, sort_by = nil)
    sort_by    ||= "hostname"
    sort_order ||= "ASC"

    headers = {
      "hostname"                        => "Hostname",
      "configuration_location_name"     => "Configuration Location",
      "configuration_organization_name" => "Configuration Organization",
      "operating_system_flavor_name"    => "Operating System",
      "provider_name"                   => "Provider",
    }

    @temp[:configured_systems] = _build_whatever_grid('configured_system', configured_systems, headers, sort_order, sort_by)
  end

  def build_pxe_img_grid(pxe_imgs, sort_order = nil, sort_by = nil)
    sort_by    ||= "name"
    sort_order ||= "ASC"

    headers = {
      "name"        => "Name",
      "description" => "Description",
    }

    @temp[:pxe_imgs] = _build_whatever_grid('pxe_img', pxe_imgs, headers, sort_order, sort_by)
  end

  def build_iso_img_grid(iso_imgs, sort_order = nil, sort_by = nil)
    sort_by    ||= "name"
    sort_order ||= "ASC"

    headers = {
      "name" => "Name",
    }

    @temp[:iso_imgs] = _build_whatever_grid('iso_img', iso_imgs, headers, sort_order, sort_by)
  end

  def build_windows_image_grid(windows_images, sort_order = nil, sort_by = nil)
    sort_by    ||= "name"
    sort_order ||= "ASC"

    headers = {
      "name"        => "Name",
      "description" => "Description",
    }

    @temp[:windows_images] = _build_whatever_grid('windows_image', windows_images, headers, sort_order, sort_by)
  end

  def build_ds_grid(datastores, sort_order = nil, sort_by = nil)
    sort_by    ||= "free_space"
    sort_order ||= "DESC"

    headers = {
      "name"        => "Name",
      "free_space"  => "Free Space",
      "total_space" => "Total Space",
    }

    integer_fields = %w(free_space total_space)

    # :datastores, not :dss
    @temp[:datastores] = _build_whatever_grid('ds', datastores, headers, sort_order, sort_by, integer_fields)
  end

  def build_vc_grid(vcs, sort_order = nil, sort_by = nil)
    sort_by    ||= "name"
    sort_order ||= "DESC"

    headers = {
      :name             => "Name",
      :description      => "Description",
      :last_update_time => "Last Updated",
    }

    integer_fields = %w(last_update_time)

    @temp[:vcs] = _build_whatever_grid('vc', vcs, headers, sort_order, sort_by, integer_fields)
  end

  def build_template_grid(templates, sort_order = nil, sort_by = nil)
    sort_by    ||= "name"
    sort_order ||= "DESC"

    headers = {
      :name             => "Name",
      :description      => "Description",
      :last_update_time => "Last Updated",
    }

    integer_fields = %w(last_update_time)

    @temp[:templates] = _build_whatever_grid('template', templates, headers, sort_order, sort_by, integer_fields)
  end

  def build_vm_grid(vms, sort_order = nil, sort_by = nil)
    sort_by    ||= "name"
    sort_order ||= "ASC"

    headers = {
      "name"                          => "Name",
      "operating_system.product_name" => "Operating System",
      "platform"                      => "Platform",
      "num_cpu"                       => "CPUs",
      "mem_cpu"                       => "Memory",
      "allocated_disk_storage"        => "Disk Size",
      "ext_management_system.name"    => ui_lookup(:model => 'ExtManagementSystem'),
      "v_total_snapshots"             => "Snapshots",
    }

    # add tenant column header to cloud workflows only
    headers["cloud_tenant"] = "Tenant" if vms.any? { |vm| vm.respond_to?(:cloud_tenant) }

    integer_fields = %w(allocated_disk_storage mem_cpu num_cpu v_total_snapshots)

    @temp[:vms] = _build_whatever_grid('vm', vms, headers, sort_order, sort_by, integer_fields)
  end

  def build_host_grid(hosts, sort_order = nil, sort_by = nil)
    sort_by    ||= "name"
    sort_order ||= "ASC"

    # need to set options from @edit/@option based upon calling screen: show/edit
    options = @edit || @options

    headers = if options[:wf].kind_of?(MiqHostProvisionWorkflow)
      # non-editable grid for host prov to display hosts being provisioned
      {
        "name"        => "Name",
        "mac_address" => "MAC Address",
      }
    else
      # editable grid for vm/migrate prov screens
      {
        "name"        => "Name",
        "v_total_vms" => "Total VMs",
        "vmm_product" => "Platform",
        "vmm_version" => "Version",
        "state"       => "State",
      }
    end

    integer_fields = %w(v_total_vms)

    @temp[:hosts] = _build_whatever_grid('host', hosts, headers, sort_order, sort_by, integer_fields, options)
  end

  def build_grid
    case @edit[:wf]
    when MiqProvisionConfiguredSystemWorkflow
      build_dialog_page_miq_provision_configured_system_workflow
    when MiqProvisionVirtWorkflow
      if @edit[:new][:current_tab_key] == :service
        if @edit[:new][:st_prov_type]
          build_vm_grid(@edit[:wf].get_field(:src_vm_id,:service)[:values],@edit[:vm_sortdir],@edit[:vm_sortcol])
        else
          @temp[:vm] = VmOrTemplate.find_by_id(@edit[:new][:src_vm_id] && @edit[:new][:src_vm_id][0])
        end
        if @edit[:wf].supports_pxe?
          build_pxe_img_grid(@edit[:wf].send("allowed_images"),@edit[:pxe_img_sortdir],@edit[:pxe_img_sortcol])
        end
        if @edit[:wf].supports_iso?
          build_iso_img_grid(@edit[:wf].send("allowed_iso_images"),@edit[:iso_img_sortdir],@edit[:iso_img_sortcol])
        end
      elsif @edit[:new][:current_tab_key] == :environment
        build_host_grid(@edit[:wf].get_field(:placement_host_name,:environment)[:values],@edit[:host_sortdir],@edit[:host_sortcol]) if !@edit[:wf].get_field(:placement_host_name,:environment).blank?
        build_ds_grid(@edit[:wf].get_field(:placement_ds_name,:environment)[:values],@edit[:ds_sortdir],@edit[:ds_sortcol]) if !@edit[:wf].get_field(:placement_ds_name,:environment).blank?
      elsif @edit[:new][:current_tab_key] == :customize
        @edit[:template_sortdir] ||= "ASC"
        @edit[:template_sortcol] ||= "name"
        if @edit[:wf].supports_customization_template?
          build_template_grid(@edit[:wf].send("allowed_customization_templates"),@edit[:template_sortdir],@edit[:template_sortcol])
        else
          build_vc_grid(@edit[:wf].get_field(:sysprep_custom_spec,:customize)[:values],@edit[:vc_sortdir],@edit[:vc_sortcol])
        end
        build_ous_tree(@edit[:wf],@edit[:new][:ldap_ous])
        @sb[:vm_os] = VmOrTemplate.find_by_id(@edit.fetch_path(:new, :src_vm_id, 0)).platform if @edit.fetch_path(:new, :src_vm_id, 0)
      elsif @edit[:new][:current_tab_key] == :purpose
        build_tags_tree(@edit[:wf],@edit[:new][:vm_tags],true)
      end
    when VmMigrateWorkflow
      if @edit[:new][:current_tab_key] == :environment
        build_host_grid(@edit[:wf].get_field(:placement_host_name,:environment)[:values],@edit[:host_sortdir],@edit[:host_sortcol]) if !@edit[:wf].get_field(:placement_host_name,:environment).blank?
        build_ds_grid(@edit[:wf].get_field(:placement_ds_name,:environment)[:values],@edit[:ds_sortdir],@edit[:ds_sortcol]) if !@edit[:wf].get_field(:placement_ds_name,:environment).blank?
      end
    else
      if @edit[:new][:current_tab_key] == :service
        build_host_grid(@edit[:wf].get_field(:src_host_ids,:service)[:values],@edit[:host_sortdir],@edit[:host_sortcol])
        build_pxe_img_grid(@edit[:wf].get_field(:pxe_image_id,:service)[:values],@edit[:pxe_img_sortdir],@edit[:pxe_img_sortcol])
        build_iso_img_grid(@edit[:wf].get_field(:iso_image_id,:service)[:values],@edit[:iso_img_sortdir],@edit[:iso_img_sortcol]) if @edit[:wf].supports_iso?
      elsif @edit[:new][:current_tab_key] == :purpose
        build_tags_tree(@edit[:wf], @edit.fetch_path(:new, tag_symbol_for_workflow), true)
      elsif @edit[:new][:current_tab_key] == :environment
        build_ds_grid(@edit[:wf].get_field(:attached_ds,:environment)[:values],@edit[:ds_sortdir],@edit[:ds_sortcol])
      elsif @edit[:new][:current_tab_key] == :customize
        build_template_grid(@edit[:wf].get_field(:customization_template_id,:customize)[:values],@edit[:template_sortdir],@edit[:template_sortcol])
      end
    end
  end

  def build_dialog_page_miq_provision_configured_system_workflow
    case @edit[:new][:current_tab_key]
    when :purpose
      build_tags_tree(@edit[:wf], @edit.fetch_path(:new, tag_symbol_for_workflow), true)
    when :service
      build_configured_system_grid(@edit[:wf].get_field(:src_configured_system_ids, :service)[:values], @edit[:configured_system_sortdir], @edit[:configured_system_sortcol])
    end
  end

  def dialog_partial_for_workflow
    case (@edit || @options).try(:[], :wf)
    when MiqProvisionVirtWorkflow                    then "shared/views/prov_dialog"
    when MiqProvisionConfiguredSystemForemanWorkflow then "prov_configured_system_foreman_dialog"
    when MiqHostProvisionWorkflow                    then "prov_host_dialog"
    when VmMigrateWorkflow                           then "prov_vm_migrate_dialog"
    end
  end

  def layout_from_tab_name(tab_name)
    case tab_name
    when "ae"                then "miq_request_ae"
    when "configured_system" then "miq_request_configured_system"
    when "host"              then "miq_request_host"
    else                          "miq_request_vm"  # Includes "vm"
    end
  end

  def sort_grid(what, values)
    sortdir = "#{what}_sortdir".to_sym
    sortcol = "#{what}_sortcol".to_sym
    unless params[:sort_choice].nil?
      if @edit[sortcol] == params[:sort_choice]                       # if same column was selected
        @edit[sortdir] = @edit[sortdir] == "ASC" ? "DESC" : "ASC"     #   switch around ascending/descending
      else
        @edit[sortdir] = "ASC"
      end
      @edit[sortcol] = params[:sort_choice]
    end

    self.send("build_#{what}_grid", values, @edit[sortdir], @edit[sortcol])
    render :update do |page|                        # Use RJS to update the display
      page.replace("prov_#{what}_div", :partial=>"miq_request/prov_#{what}_grid",:locals=>{:field_id=>params[:field_id]})
      page << "miqSparkle(false);"
    end
  end

  def tag_symbol_for_workflow
    (@edit || @options)[:wf].kind_of?(MiqHostProvisionWorkflow) ? :tag_ids : :vm_tags
  end

  def validate_fields
    # Update/create returned false, validation failed
    @edit[:wf].get_dialog_order.each do |d|                           # Go thru all dialogs, in order that they are displayed
      @edit[:wf].get_all_fields(d).keys.each do |f|                 # Go thru all field
        field = @edit[:wf].get_field(f, d)
        if !field[:error].blank?
          @error_div ||= "#{d}"
          add_flash(field[:error], :error)
        end
      end
    end
  end

  def validate_preprov
    @edit[:wf].get_dialog_order.each do |d|
      @edit[:wf].get_all_fields(d).keys.each do |f|
        field = @edit[:wf].get_field(f, d)
        @edit[:wf].validate(@edit[:new])
        unless field[:error].nil?
          @error_div ||= "#{d}"
          add_flash(field[:error], :error)
        end
      end
    end
  end

  def prov_request_cancel_submit_response
    if @explorer
      @sb[:action] = nil
      replace_right_cell
    else
      render :update do |page|
        if @breadcrumbs && (@breadcrumbs.empty? || @breadcrumbs.last[:url] == "/vm/show_list")
          page.redirect_to :action => "show_list", :controller => "vm"
        else
          # had to get id from breadcrumbs url,
          # because there is no params[:id] when cancel is pressed on copy Request screen.
          url = @breadcrumbs.last[:url].split('/')
          page.redirect_to :controller => url[1], :action => url[2], :id => url[3]
        end
      end
    end
  end

  def prov_req_submit
    id = session[:edit][:req_id] || "new"
    return unless load_edit("prov_edit__#{id}","show_list")
    @edit[:new][:schedule_time] = @edit[:new][:schedule_time].in_time_zone("Etc/UTC") if @edit[:new][:schedule_time]
    request = @edit[:req_id] ? @edit[:wf].update_request(@edit[:req_id], @edit[:new], session[:userid]) : @edit[:wf].create_request(@edit[:new], session[:userid])
    validate_fields
    if !@flash_array
      @breadcrumbs.pop if @breadcrumbs
      typ = @edit[:org_controller]
      case typ
      when "vm"
        title = "VMs"
      when "miq_template"
        title = "Templates"
      else
        title = "Hosts"
      end
      flash = @edit[:req_id] == nil ? _("%{typ} Request was Submitted, you will be notified when your %{title} are ready") % {:typ=>@edit[:prov_type], :title=>title} : _("%{typ} Request was re-submitted, you will be notified when your %{title} are ready") % {:typ=>@edit[:prov_type], :title=>title}
      @explorer = @edit[:explorer] ? @edit[:explorer] : false
      @sb[:action] = @edit = session[:edit] =  nil                                                # Clear out session[:edit]
      if role_allows(:feature => "miq_request_show_list", :any => true)
        render :update do |page|
          page.redirect_to :controller => 'miq_request',
                           :action     => 'show_list',
                           :flash_msg  => flash,
                           :typ        => typ
        end
      else
        add_flash(flash)
        prov_request_cancel_submit_response
      end
    else
      @edit[:new][:current_tab_key] = @error_div.split('_')[0].to_sym if @error_div
      @edit[:wf].refresh_field_values(@edit[:new],session[:userid])
      build_grid
      render :update do |page|                    # Use JS to update the display
        page.replace("prov_wf_div", :partial=>"/miq_request/prov_wf") if @error_div
        page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      end
    end
  end

  # Get variables from provisioning form
  def prov_get_form_vars
    if params[:ids_checked]                         # User checked/unchecked a tree node
      ids = params[:ids_checked].split(",")
      # for some reason if tree is not expanded clicking on radiobuttons this.getAllChecked() sends up extra blanks
      @edit.store_path(:new, tag_symbol_for_workflow, ids.select(&:present?).collect(&:to_i))
    end
    id = params[:ou_id].gsub(/_-_/,",") if params[:ou_id]
    @edit[:new][:ldap_ous] = id.match(/(.*)\,(.*)/)[1..2] if id                       # ou selected in a tree

    @edit[:new][:start_date]    = params[:miq_date_1] if params[:miq_date_1]
    @edit[:new][:start_hour]    = params[:start_hour] if params[:start_hour]
    @edit[:new][:start_min]     = params[:start_min] if params[:start_min]
    @edit[:new][:schedule_time] = Time.zone.parse("#{@edit[:new][:start_date]} #{@edit[:new][:start_hour]}:#{@edit[:new][:start_min]}")

    params.keys.each do |key|
      next unless key.include?("__")
      d, f  = key.split("__")  # Parse dialog and field names from the parameter key
      field = @edit[:wf].get_field(f.to_sym, d.to_sym)  # Get the field hash
      val   =
        case field[:data_type]  # Get the value, convert to integer or boolean if needed
        when :integer
          params[key].to_i
        when :boolean
          params[key].to_s == "true"
        else
          params[key]
        end

      if field[:values]                                                         # If a choice was made
        if field[:values].kind_of?(Hash)
          #set an array of selected ids for security groups field
          if f == "security_groups"
            if params[key] == ""
              @edit[:new][f.to_sym] = [nil]
            else
              @edit[:new][f.to_sym] = Array.new
              params[key].split(",").each { |v| @edit[:new][f.to_sym].push(v.to_i) }
            end
          else
            @edit[:new][f.to_sym] = [val, field[:values][val]]                    # Save [value, description]
          end
        else
          field[:values].each do |v|
            if v.class.name == "MiqHashStruct" && v.evm_object_class == :Storage
              if ["miq_template","service_template","vm"].include?(@edit[:org_controller])
                if params[key] == "__DS__NONE__"                                  # Added this to deselect datastore in grid
                  @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
                elsif v.id.to_i == val.to_i
                  @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
                end
              else
                if params[key] == "__DS__NONE__"                                  # Added this to deselect datastore in grid
                  @edit[:new][f.to_sym] = Array.new                           # Save [value, description]
                elsif v.id.to_i == val.to_i
                  if @edit[:new][f.to_sym].include?(val)
                    @edit[:new][f.to_sym].delete_if {|x| x == val }
                  else
                    @edit[:new][f.to_sym].push(val)                             # Save [value, description]
                  end
                end
              end
            elsif v.class.name == "MiqHashStruct" && v.evm_object_class == :Host
              if params[key] == "__HOST__NONE__"                                  # Added this to deselect datastore in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id.to_i == val.to_i
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            elsif v.class.name == "MiqHashStruct" && v.evm_object_class == :Vm
              if params[key] == "__VM__NONE__"                                  # Added this to deselect datastore in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id.to_i == val.to_i
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            elsif v.class.name == "MiqHashStruct" && (v.evm_object_class == :PxeImage || v.evm_object_class == :WindowsImage)
              if params[key] == "__PXE_IMG__NONE__"                                 # Added this to deselect datastore in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id == val
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            elsif v.class.name == "MiqHashStruct" && v.evm_object_class == :IsoImage
              if params[key] == "__ISO_IMG__NONE__"                                 # Added this to deselect datastore in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id == val
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            elsif v.class.name == "MiqHashStruct" && v.evm_object_class == :CustomizationTemplate
              if params[key] == "__TEMPLATE__NONE__"                                  # Added this to deselect datastore in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id.to_i == val.to_i
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            elsif v.kind_of?(VimHash) || (v.class.name == "MiqHashStruct" && v.evm_object_class == :CustomizationSpec)
              if params[key] == "__VC__NONE__"                                  # Added this to deselect custom_spec in grid
                @edit[:new][f.to_sym] = [nil, nil]                              # Save [value, description]
              elsif v.id.to_i == val.to_i
                @edit[:new][f.to_sym] = [val, v.name]                             # Save [value, description]
              end
            else
              if v[1].to_i == val.to_i
                @edit[:new][f.to_sym] = [val, v[0]]                             # Save [value, description]
              end
            end
          end
        end
        begin
          @edit[:wf].refresh_field_values(@edit[:new],session[:userid])           # Refresh the workflow with new field values based on options, need to pass userid there
        rescue StandardError => bang
          add_flash(bang, :error)
          @edit[:new][f.to_sym] = val                                             # Save value
          return false                                                            # No need to refresh dialog divs
        else
          return true
        end                                                                   # Return true, refresh dialog divs
      else
        @edit[:new][f.to_sym] = val                                             # Save value
        return false                                                            # No need to refresh dialog divs
      end
    end
  end

  def prov_set_show_vars
    @showtype = "main"
    @options = @miq_request.get_options                         # Get the provision options from the request record
    @options[:org_controller] = @miq_request.resource_type == "MiqHostProvisionRequest" ? "host" : "vm"
    if @options[:schedule_time]
      @options[:schedule_time] = format_timezone(@options[:schedule_time],Time.zone,"raw")
      @options[:start_date] = "#{@options[:schedule_time].month}/#{@options[:schedule_time].day}/#{@options[:schedule_time].year}"  # Set the start date
      @options[:start_hour] = "#{@options[:schedule_time].hour}"
      @options[:start_min] = "#{@options[:schedule_time].min}"
    end
    drop_breadcrumb( {:name=>@miq_request.description.to_s.split(' submitted')[0], :url=>"/miq_request/show/#{@miq_request.id}"} )
    if @miq_request.workflow_class
      options = Hash.new
      begin
        options[:wf] = @miq_request.workflow_class.new(@options,session[:userid])                # Create a new provision workflow for this edit session
      rescue MiqException::MiqVmError => bang
        @no_wf_msg = _("Cannot create Request Info, error: ") << bang.message
      end
      if options[:wf]
        options[:wf].init_from_dialog(@options,session[:userid])                                 # Create a new provision workflow for this edit session
        #setting active tab to first visible tab
        options[:wf].get_dialog_order.each do |d|
          if options[:wf].get_dialog(d)[:display] == :show
            @options[:current_tab_key] = d
            break
          end
        end
        @options[tag_symbol_for_workflow] ||= []  # Initialize if came back nil from record
        build_tags_tree(options[:wf], @options[tag_symbol_for_workflow], false) if @miq_request.resource_type != "VmMigrateRequest"
        if !["MiqHostProvisionRequest", "VmMigrateRequest"].include?(@miq_request.resource_type)
          build_ous_tree(options[:wf],@options[:ldap_ous])
          @sb[:vm_os] = VmOrTemplate.find_by_id(@options[:src_vm_id][0]).platform if @options[:src_vm_id] && @options[:src_vm_id][0]
        end
        @options[:wf] = options[:wf]
      end
    else
      @options = @miq_request.options
      @options[:memory], @options[:mem_typ] = reconfigure_calculations(@options[:vm_memory]) if @options[:vm_memory]
      @force_no_grid_xml   = true
      @view, @pages = get_view(Vm, :view_suffix=>"VmReconfigureRequest", :where_clause=>["vms.id IN (?)",@miq_request.options[:src_ids]]) # Get the records (into a view) and the paginator
    end
    @temp[:user] = User.find_by_userid(@miq_request.stamped_by)
  end

  # Set form variables for provision request
  def prov_set_form_vars(req = nil)
    @edit                     ||= {}
    session[:prov_options]      = @options = nil  # Clearing out options that were set on show screen
    @edit[:req_id]              = req.try(:id)    # Save existing request record id, if passed in
    @edit[:key]                 = "prov_edit__#{@edit[:req_id] || "new"}"
    options                     = req.try(:get_options) || {}  # Use existing request options, if passed in
    @edit[:new]                 = options unless @workflow_exists
    @edit[:org_controller]      = params[:org_controller] if params[:org_controller]  # request originated from controller
    @edit[:wf], pre_prov_values = workflow_instance_from_vars(req)

    if @edit[:wf]
      @edit[:wf].get_dialog_order.each do |d|
        if @edit[:wf].get_dialog(d)[:display] == :show
          @edit[:new][:current_tab_key] = d
          break
        end
      end
      @edit[:buttons] = @edit[:wf].get_buttons
      @edit[:wf].init_from_dialog(@edit[:new], session[:userid]) # Create a new provision workflow for this edit session
      @timezone_offset = get_timezone_offset
      if @edit[:new][:schedule_time]
        @edit[:new][:schedule_time] = format_timezone(@edit[:new][:schedule_time], Time.zone, "raw")
        @edit[:new][:start_date] = "#{@edit[:new][:schedule_time].month}/#{@edit[:new][:schedule_time].day}/#{@edit[:new][:schedule_time].year}" # Set the start date
        if params[:id]
          @edit[:new][:start_hour] = "#{@edit[:new][:schedule_time].hour}"
          @edit[:new][:start_min] = "#{@edit[:new][:schedule_time].min}"
        else
          @edit[:new][:start_hour] = "00"
          @edit[:new][:start_min] = "00"
        end
      end
      @edit[:new][tag_symbol_for_workflow] ||= []  # Initialize for new record
      @edit[:current] ||= {}
      @edit[:current] = copy_hash(@edit[:new])
      # Give the model a change to modify the dialog based on the default settings
      #common grids
      @edit[:wf].refresh_field_values(@edit[:new], session[:userid])
      if pre_prov_values
        @edit[:new] = @edit[:new].delete_nils
        @edit[:new] = @edit[:new].merge pre_prov_values.select { |k| !@edit[:new].keys.include?(k) }
      end

      if @edit[:wf].kind_of?(MiqProvisionConfiguredSystemForemanWorkflow)
        # BD TODO
      else
        @edit[:ds_sortdir] ||= "DESC"
        @edit[:ds_sortcol] ||= "free_space"
        @edit[:host_sortdir] ||= "ASC"
        @edit[:host_sortcol] ||= "name"
        build_host_grid(@edit[:wf].send("allowed_hosts"), @edit[:host_sortdir], @edit[:host_sortcol])
        build_ds_grid(@edit[:wf].send("allowed_storages"), @edit[:ds_sortdir], @edit[:ds_sortcol])
        if @edit[:wf].kind_of?(MiqProvisionWorkflow)
          @edit[:vm_sortdir] ||= "ASC"
          @edit[:vm_sortcol] ||= "name"
          @edit[:vc_sortdir] ||= "ASC"
          @edit[:vc_sortcol] ||= "name"
          @edit[:template_sortdir] ||= "ASC"
          @edit[:template_sortcol] ||= "name"
          build_vm_grid(@edit[:wf].send("allowed_templates"), @edit[:vm_sortdir], @edit[:vm_sortcol])
          build_tags_tree(@edit[:wf], @edit[:new][:vm_tags], true)
          build_ous_tree(@edit[:wf], @edit[:new][:ldap_ous])
          if @edit[:wf].supports_pxe?
            build_pxe_img_grid(@edit[:wf].send("allowed_images"), @edit[:pxe_img_sortdir], @edit[:pxe_img_sortcol])
            build_host_grid(@edit[:wf].send("allowed_hosts"), @edit[:host_sortdir], @edit[:host_sortcol])
            build_template_grid(@edit[:wf].send("allowed_customization_templates"), @edit[:template_sortdir], @edit[:template_sortcol])
          elsif @edit[:wf].supports_iso?
            build_iso_img_grid(@edit[:wf].send("allowed_iso_images"), @edit[:iso_img_sortdir], @edit[:iso_img_sortcol])
          else
            build_vc_grid(@edit[:wf].send("allowed_customization_specs"), @edit[:vc_sortdir], @edit[:vc_sortcol])
          end
        elsif @edit[:wf].kind_of?(VmMigrateWorkflow)
        else
          @edit[:template_sortdir] ||= "ASC"
          @edit[:template_sortcol] ||= "name"
          build_tags_tree(@edit[:wf], @edit[:new][:tag_ids], true)
          build_pxe_img_grid(@edit[:wf].send("allowed_images"), @edit[:pxe_img_sortdir], @edit[:pxe_img_sortcol])
          build_iso_img_grid(@edit[:wf].send("allowed_iso_images"), @edit[:iso_img_sortdir], @edit[:iso_img_sortcol])
          build_host_grid(@edit[:wf].send("allowed_hosts"), @edit[:host_sortdir], @edit[:host_sortcol])
          build_template_grid(@edit[:wf].send("allowed_customization_templates"), @edit[:template_sortdir], @edit[:template_sortcol])
        end
      end
    else
      @edit[:current] ||= {}
      @edit[:current] = copy_hash(@edit[:new])
    end
  end

  def workflow_instance_from_vars(req)
    options         = {}
    pre_prov_values = nil
    if ["miq_template", "service_template", "vm"].include?(@edit[:org_controller])
      if params[:prov_type] && !req  # only do this new requests
        @edit[:prov_id] = params[:prov_id]
        wf_type =
          if params[:prov_type] == "migrate"
            @edit[:prov_type]     = "VM Migrate"
            @edit[:new][:src_ids] = params[:prov_id]
            VmMigrateWorkflow
          else
            @edit[:prov_type] = "VM Provision"
            if @edit[:org_controller] == "service_template"
              options[:service_template_request] = true
              MiqProvisionVmwareWorkflow
            else
              options[:src_vm_id]    = @edit[:prov_id]
              options[:request_type] = params[:prov_type].to_sym
              MiqProvisionWorkflow.class_for_source(options[:src_vm_id])
            end
          end
      else
        options[:initial_pass]             = true  unless req
        options[:service_template_request] = true  if @edit[:org_controller] == "service_template"
        options[:use_pre_dialog]           = false if @workflow_exists
        # setting class to MiqProvisionVmwareWorkflow for requests where src_vm_id is not already set, i.e catalogitem
        src_vm_id =
          if @edit.fetch_path(:new, :src_vm_id, 0).present?
            @edit[:new][:src_vm_id]
          elsif @src_vm_id || params[:src_vm_id]  # Set vm id if pre-prov chose one
            options[:src_vm_id] = [@src_vm_id || params[:src_vm_id].to_i]
          end

        wf_type =
          if req.try(:type) == "VmMigrateRequest"
            VmMigrateWorkflow
          elsif src_vm_id.try(:first).present?
            MiqProvisionWorkflow.class_for_source(src_vm_id[0])
          elsif @edit[:st_prov_type]
            MiqProvisionWorkflow.class_for_platform(@edit[:st_prov_type])
          else # handle copy button for host provisioning
            MiqHostProvisionWorkflow
          end
        pre_prov_values = copy_hash(@edit[:wf].values) if @edit[:wf]

        @edit[:prov_type]   = req.try(:request_type) && req.request_type_display
        @edit[:prov_type] ||= req.try(:type) == "VmMigrateRequest" ? "VM Migrate" : "VM Provision"
      end
    elsif @edit[:org_controller] == "configured_system"
      @edit[:prov_type] = "ConfiguredSystem"
      @edit[:new][:src_configured_system_ids] = params[:prov_id].kind_of?(Array) ? params[:prov_id] : [params[:prov_id]]
      wf_type = MiqProvisionConfiguredSystemForemanWorkflow
    else
      @edit[:prov_type] = "Host"
      if @edit[:new].empty?
        # multiple / single hosts selected, src_host_ids should always be an array
        @edit[:new][:src_host_ids] = params[:prov_id].kind_of?(Array) ? params[:prov_id] : [params[:prov_id]]
      end
      wf_type = MiqHostProvisionWorkflow
    end

    [wf_type.new(@edit[:new], session[:userid], options), pre_prov_values]  # Return the new workflow and any pre_prov_values
  rescue MiqException::MiqVmError => bang
    # only add this message if showing a list of Catalog items, show screen already handles this
    @no_wf_msg = _("Cannot create Request Info, error: ") << bang.message
  end

  def build_ous_tree(wf,ldap_ous)
    dcs = wf.send("allowed_ous_tree")
    @curr_dc = nil
    # Build the default filters tree for the search views
    all_dcs = []                        # Array to hold all CIs
    dcs.each_with_index do |dc,i| # Go thru all of the Searches
      @curr_tag = dc[0]
      @ci_node = {
        :key         => dc[0],
        :title       => dc[0],
        :tooltip     => dc[0],
        :icon        => "folder.png",
        :cfmeNoClick => true,
        :addClass    => "cfme-bold-node",
        :expand      => true
      }
      @ci_kids = []
      dc[1].each_with_index do |ou,j|
        id = ou[1][:ou].join(",")
        id.gsub!(/,/,"_-_")         # Workaround for save/load openstates, replacing commas in ou array
        temp = {
          :key     => id,
          :tooltip => ou[0],
          :title   => ou[0],
          :icon    => "group.png"
        }
        if ldap_ous == ou[1][:ou]
          #expand selected nodes parents when editing existing record
          @expand_parent_nodes = id
          temp[:addClass] = "cfme-blue-bold-node"
        else
          temp[:addClass] = "cfme-no-cursor-node"
        end
        @ou_kids = []
        ou[1].each do |lvl1|
          if lvl1.kind_of?(Array) && lvl1[0] != :ou && lvl1[0] != :path
            kids = get_ou_kids(lvl1,ldap_ous)
            @ou_kids.push(kids) unless @ou_kids.include?(kids)
          end
        end
        temp[:children] = @ou_kids unless @ou_kids.blank?
        @ci_kids.push(temp) unless @ci_kids.include?(temp)
      end
      if i == dcs.length-1            # Adding last node
        @ci_node[:children] = @ci_kids unless @ci_kids.blank?
        all_dcs.push(@ci_node)
      end
    end
    unless all_dcs.blank?
      @temp[:ldap_ous_tree] = all_dcs.to_json  # Add ci node array to root of tree
    else
      @temp[:ldap_ous_tree] = nil
    end
    session[:tree_name] = "ldap_ous_tree"
  end

  def get_ou_kids(node,ldap_ous)
    id = node[1][:ou].join(",")
    id.gsub!(/,/,"_-_")       # Workaround for save/load openstates, replacing commas in ou array
    kids = {
      :key      => id,
      :title    => node[0],
      :tooltip  => node[0],
      :icon     => "group.png"
    }

    if ldap_ous == node[1][:ou]
      kids[:addClass] = "cfme-blue-bold-node"
      @expand_parent_nodes = id
    else
      kids[:addClass] = "cfme-no-cursor-node"
    end

    ou_kids = []
    node[1].each do |k|
      if k.kind_of?(Array) && k[0] != :ou && k[0] != :path
        ou = get_ou_kids(k,ldap_ous)
        ou_kids.push(ou) unless ou_kids.include?(ou)
      end
      kids[:children] = ou_kids unless ou_kids.blank?
    end
    kids
  end

  def build_tags_tree(wf,vm_tags,edit_mode)
    tags = wf.send("allowed_tags")
    @curr_tag = nil
    # Build the default filters tree for the search views
    all_tags = []                          # Array to hold all CIs
    kids_checked = false
    tags.each_with_index do |t,i| # Go thru all of the Searches
      if @curr_tag.blank? || @curr_tag != t[:name]
        if @curr_tag != t[:name] && @ci_node
          @ci_node[:expand] = true if kids_checked
          kids_checked = false
          @ci_node[:children] = @ci_kids unless @ci_kids.blank?
          all_tags.push(@ci_node) unless @ci_kids.blank?
        end
        @curr_tag = t[:name]
        @ci_node = {}                       # Build the ci node
        @ci_node[:key] = t[:id].to_s
        @ci_node[:title] = t[:description]
        @ci_node[:title] += " *" if t[:single_value]
        @ci_node[:tooltip] = t[:description]
        @ci_node[:addClass] = "cfme-no-cursor-node"      # No cursor pointer
        @ci_node[:icon] = "folder.png"
        @ci_node[:hideCheckbox] = @ci_node[:cfmeNoClick] = true
        @ci_node[:addClass] = "cfme-bold-node"  # Show node as different
        @ci_kids = []
      end
      if !@curr_tag.blank? && @curr_tag == t[:name]
        t[:children].each do |c|
          temp = {}
          temp[:key] = c[0].to_s
          #only add cfme_parent_key for single value tags, need to use in JS onclick handler
          temp[:cfme_parent_key] = t[:id].to_s if t[:single_value]
          temp[:title] = temp[:tooltip] = c[1][:description]
          temp[:addClass] = "cfme-no-cursor-node"
          temp[:icon] = "tag.png"
          if edit_mode              #Don't show checkboxes/radio buttons in non-edit mode
            if vm_tags && vm_tags.include?(c[0].to_i)
              temp[:select] = true
              kids_checked = true
            else
              temp[:select] = false
            end
            if @edit && @edit[:current][tag_symbol_for_workflow] != @edit[:new][tag_symbol_for_workflow]
              #checking to see if id is in current but not in new, change them to blue OR if id is in current but deleted from new
              if (!@edit[:current][tag_symbol_for_workflow].include?(c[0].to_i) && @edit[:new][tag_symbol_for_workflow].include?(c[0].to_i)) ||
                  (!@edit[:new][tag_symbol_for_workflow].include?(c[0].to_i) && @edit[:current][tag_symbol_for_workflow].include?(c[0].to_i))
                temp[:addClass] = "cfme-blue-bold-node"
              end
            end
            @ci_kids.push(temp) unless @ci_kids.include?(temp)
          else
            temp[:hideCheckbox] = true
            @ci_kids.push(temp) unless @ci_kids.include?(temp) || !vm_tags.include?(c[0].to_i)
          end
        end
      end
      if i == tags.length-1           # Adding last node
        @ci_node[:expand] = true if kids_checked
        kids_checked = false
        @ci_node[:children] = @ci_kids unless @ci_kids.blank?
        all_tags.push(@ci_node) unless @ci_kids.blank?
      end
    end
    @temp[:all_tags_tree] = all_tags.to_json # Add ci node array to root of tree
    session[:tree] = "all_tags"
    session[:tree_name] = "all_tags_tree"
  end
end
