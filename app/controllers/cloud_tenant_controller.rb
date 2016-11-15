class CloudTenantController < ApplicationController
  include Mixins::GenericShowMixin
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericListMixin

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit]                                  # Restore @edit for adv search box
    params[:display] = @display if %w(vms instances images).include?(@display)
    params[:page] = @current_page unless @current_page.nil?   # Save current page for list refresh
    return tag("CloudTenant") if params[:pressed] == 'cloud_tenant_tag'
    if params[:pressed].starts_with?("vm_", # Handle buttons from sub-items screen
                                     "miq_template_",
                                     "guest_",
                                     "image_",
                                     "instance_")

      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)
      return if ["#{pfx}_policy_sim", "#{pfx}_compare", "#{pfx}_tag", "#{pfx}_retire",
                 "#{pfx}_protect", "#{pfx}_ownership", "#{pfx}_refresh", "#{pfx}_right_size",
                 "#{pfx}_reconfigure"].include?(params[:pressed]) &&
                @flash_array.nil?

      unless ["#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone",
              "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show
      end
    elsif params[:pressed] == "cloud_tenant_new"
      javascript_redirect :action => "new"
      return
    elsif params[:pressed] == "cloud_tenant_edit"
      javascript_redirect :action => "edit", :id => get_checked_cloud_tenant_id(params)
      return
    elsif params[:pressed] == 'cloud_tenant_delete'
      delete_cloud_tenants
      render_flash
      return
    elsif params[:pressed] == "custom_button"
      custom_buttons
      # custom button screen, so return, let custom_buttons method handle everything
      return
    end
    render_button_partial(pfx)
  end

  def self.display_methods
    %w(instances images security_groups cloud_volumes cloud_volume_snapshots cloud_object_store_containers floating_ips
       network_ports cloud_networks cloud_subnets network_routers)
  end

  def get_checked_cloud_tenant_id(params)
    if params[:id]
      checked_cloud_tenant_id = params[:id]
    else
      checked_cloud_tenants = find_checked_items
      checked_cloud_tenant_id = checked_cloud_tenants[0] if checked_cloud_tenants.length == 1
    end
    checked_cloud_tenant_id
  end

  def new
    assert_privileges("cloud_tenant_new")
    @tenant = CloudTenant.new
    @in_a_form = true
    @ems_choices = {}
    ManageIQ::Providers::Openstack::CloudManager.all.each { |ems|
      @ems_choices[ems.name] = ems.id
      # keystone v3 allows for hierarchical tenants
      if ems.api_version == "v3"
        ems.cloud_tenants.each { |ems_cloud_tenant|
          tenant_choice_name = ems.name + " (" + ems_cloud_tenant.name + ")"
          tenant_choice_id = ems.id.to_s + ":" + ems_cloud_tenant.id.to_s
          @ems_choices[tenant_choice_name] = tenant_choice_id
        }
      end
    }
    drop_breadcrumb(
      :name => _("Add New %{model}") % {:model => ui_lookup(:table => 'cloud_tenant')},
      :url  => "/cloud_tenant/new"
    )
  end

  def create
    assert_privileges("cloud_tenant_new")
    case params[:button]
    when "cancel"
      javascript_redirect :action => 'show_list',
                          :flash_msg => _("Add of new %{model} was cancelled by the user") % {:model => ui_lookup(:table => 'cloud_tenant')}

    when "add"
      @tenant = CloudTenant.new
      options = form_params
      ems = find_by_id_filtered(ExtManagementSystem, options[:ems_id])
      options.delete(:ems_id)

      task_id = CloudTenant.create_cloud_tenant_queue(session[:userid], ems, options)

      add_flash(_("Cloud tenant creation failed: Task start failed: ID [%{id}]") %
                {:id => task_id.inspect}, :error) unless task_id.kind_of?(Fixnum)

      if @flash_array
        javascript_flash(:spinner_off => true)
      else
        initiate_wait_for_task(:task_id => task_id, :action => "create_finished")
      end
    end
  end

  def create_finished
    task_id = session[:async][:params][:task_id]
    tenant_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("%{model} \"%{name}\" created") % {
                  :model => ui_lookup(:table => 'cloud_tenant'),
                  :name  => tenant_name
                })
    else
        add_flash(_("Unable to create %{model} \"%{name}\": %{details}") % {
                    :model   => ui_lookup(:table => 'cloud_tenant'),
                    :name    => tenant_name,
                    :details => task.message
                  }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show_list"
  end

  def edit
    assert_privileges("cloud_tenant_edit")
    @tenant = find_by_id_filtered(CloudTenant, params[:id])
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Edit %{model} \"%{name}\"") % {:model => ui_lookup(:table => 'cloud_tenant'), :name => @tenant.name},
      :url  => "/cloud_tenant/edit/#{@tenant.id}"
    )
  end

  def update
    assert_privileges("cloud_tenant_edit")
    @tenant = find_by_id_filtered(CloudTenant, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'cloud_tenant'),
        :name  => @tenant.name
      })

    when "save"
      options = form_params
      task_id = @tenant.update_cloud_tenant_queue(session[:userid], options)

      add_flash(_("Cloud tenant creation failed: Task start failed: ID [%{id}]") %
                {:id => task_id.inspect}, :error) unless task_id.kind_of?(Fixnum)

      if @flash_array
        javascript_flash(:spinner_off => true)
      else
        initiate_wait_for_task(:task_id => task_id, :action => "update_finished")
      end
    end
  end

  def update_finished
    task_id = session[:async][:params][:task_id]
    tenant_id = session[:async][:params][:id]
    tenant_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("%{model} \"%{name}\" updated") % {
                  :model => ui_lookup(:table => 'cloud_tenant'),
                  :name  => tenant_name
                })
    else
        add_flash(_("Unable to update %{model} \"%{name}\": %{details}") % {
                    :model   => ui_lookup(:table => 'cloud_tenant'),
                    :name    => tenant_name,
                    :details => task.message
                  }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show", :id => tenant_id
  end

  def cloud_tenant_form_fields
    assert_privileges("cloud_tenant_edit")
    tenant = find_by_id_filtered(CloudTenant, params[:id])
    render :json => {
      :name => tenant.name
    }
  end

  def delete_cloud_tenants
    assert_privileges("cloud_tenant_delete")

    tenants = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "cloud_tenant")
                find_checked_items
              else
                [params[:id]]
              end

    if tenants.empty?
      add_flash(_("No %{models} were selected for deletion.") % {
        :models => ui_lookup(:tables => "cloud_tenant")
      }, :error)
    end

    tenants_to_delete = []
    tenants.each do |tenant_id|
      tenant = CloudTenant.find_by_id(tenant_id)
      if tenant.nil?
        add_flash(_("%{model} no longer exists.") % {:model => ui_lookup(:table => "cloud_tenant")}, :error)
      elsif !tenant.vms.empty?
        add_flash(_("%{model} \"%{name}\" cannot be removed because it is attached to one or more %{instances}") % {
          :model     => ui_lookup(:table => 'cloud_tenant'),
          :name      => tenant.name,
          :instances => ui_lookup(:tables => 'vm_cloud')}, :warning)
      else
        tenants_to_delete.push(tenant)
      end
    end
    process_cloud_tenants(tenants_to_delete, "destroy") unless tenants_to_delete.empty?

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "cloud_tenant"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected %{model} was deleted") % {:model => ui_lookup(:table => "cloud_tenant")})
      end
    end
  end

  def cancel_action(message)
    session[:edit] = nil
    @breadcrumbs.pop if @breadcrumbs
    javascript_redirect :action    => @lastaction,
                        :id        => @tenant.id,
                        :display   => session[:cloud_tenant_display],
                        :flash_msg => message
  end

  private

  def form_params
    options = {}
    options[:name] = params[:name] if params[:name]
    if params[:ems_id]
      ems_id_array = params[:ems_id].split(":")
      options[:ems_id] = ems_id_array[0]
      if ems_id_array.length > 1
        parent_id = find_by_id_filtered(CloudTenant, ems_id_array[1]).ems_ref
        options[:parent_id] = parent_id
      end
    end
    options
  end

  # dispatches tasks to multiple tenants
  def process_cloud_tenants(tenants, task)
    return if tenants.empty?

    if task == "destroy"
      tenants.each do |tenant|
        audit = {
          :event        => "cloud_tenant_record_delete_initiateed",
          :message      => "[#{tenant.name}] Record delete initiated",
          :target_id    => tenant.id,
          :target_class => "CloudTenant",
          :userid       => session[:userid]
        }
        AuditEvent.success(audit)
        tenant.delete_cloud_tenant_queue(session[:userid])
      end
      add_flash(n_("Delete initiated for %{number} Cloud Tenant.",
                   "Delete initiated for %{number} Cloud Tenants.",
                   tenants.length) % {:number => tenants.length})
    end
  end

  def render_button_partial(pfx)
    if @flash_array && params[:pressed] == "#{@table_name}_delete" && @single_delete
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

  def get_session_data
    @title      = _("Cloud Tenant")
    @layout     = "cloud_tenant"
    @lastaction = session[:cloud_tenant_lastaction]
    @display    = session[:cloud_tenant_display]
    @filters    = session[:cloud_tenant_filters]
    @catinfo    = session[:cloud_tenant_catinfo]
  end

  def set_session_data
    session[:cloud_tenant_lastaction] = @lastaction
    session[:cloud_tenant_display]    = @display unless @display.nil?
    session[:cloud_tenant_filters]    = @filters
    session[:cloud_tenant_catinfo]    = @catinfo
  end

  menu_section :clo
end
