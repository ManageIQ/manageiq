class CloudVolumeController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def index
    redirect_to :action => 'show_list'
  end

  def get_checked_volume_id(params)
    if params[:id]
      checked_volume_id = params[:id]
    else
      checked_volumes = find_checked_items
      checked_volume_id = checked_volumes[0] if checked_volumes.length == 1
    end
    checked_volume_id
  end

  # handle buttons pressed on the button bar
  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:display] = @display if %w(vms instances images).include?(@display)
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh

    if params[:pressed].starts_with?("instance_")
      pfx = pfx_for_vm_button_pressed(params[:pressed])
      process_vm_buttons(pfx)
      # Control transferred to another screen, so return
      return if ["#{pfx}_policy_sim", "#{pfx}_compare", "#{pfx}_tag", "#{pfx}_retire", "#{pfx}_resize",
                 "#{pfx}_protect", "#{pfx}_ownership", "#{pfx}_refresh", "#{pfx}_right_size",
                 "#{pfx}_resize", "#{pfx}_live_migrate", "#{pfx}_evacuate"].include?(params[:pressed]) && @flash_array.nil?
      unless ["#{pfx}_edit", "#{pfx}_miq_request_new", "#{pfx}_clone",
              "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
        @refresh_div = "main_div"
        @refresh_partial = "layouts/gtl"
        show # Handle EMS buttons
      end
    else
      @refresh_div = "main_div"
      return tag("CloudVolume") if params[:pressed] == "cloud_volume_tag"
      delete_volumes if params[:pressed] == 'cloud_volume_delete'
    end

    if params[:pressed] == "cloud_volume_attach"
      checked_volume_id = get_checked_volume_id(params)
      javascript_redirect :action => "attach", :id => checked_volume_id
    elsif params[:pressed] == "cloud_volume_detach"
      checked_volume_id = get_checked_volume_id(params)
      @volume = find_by_id_filtered(CloudVolume, checked_volume_id)
      if @volume.attachments.empty?
        render_flash(_("%{volume} \"%{volume_name}\" is not attached to any %{instances}") % {
                     :volume      => ui_lookup(:table => 'cloud_volume'),
                     :volume_name => @volume.name,
                     :instances   => ui_lookup(:tables => 'vm_cloud')}, :error)
      else
        javascript_redirect :action => "detach", :id => checked_volume_id
      end
    elsif params[:pressed] == "cloud_volume_edit"
      checked_volume_id = get_checked_volume_id(params)
      javascript_redirect :action => "edit", :id => checked_volume_id
    elsif params[:pressed] == "cloud_volume_new"
      javascript_redirect :action => "new"
    elsif params[:pressed] == "cloud_volume_backup_create"
      checked_volume_id = get_checked_volume_id(params)
      javascript_redirect :action => "backup_new", :id => checked_volume_id
    elsif params[:pressed] == "cloud_volume_backup_restore"
      checked_volume_id = get_checked_volume_id(params)
      javascript_redirect :action => "backup_select", :id => checked_volume_id
    elsif !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    elsif params[:pressed].ends_with?("_edit") || ["#{pfx}_miq_request_new", "#{pfx}_clone",
                                                   "#{pfx}_migrate", "#{pfx}_publish"].include?(params[:pressed])
      render_or_redirect_partial(pfx)
    else
      render_flash
    end
  end

  def show
    @display = params[:display] || "main" unless control_selected?
    @showtype = @display
    @lastaction = "show"

    @volume = @record = identify_record(params[:id])
    return if record_no_longer_exists?(@volume)

    @gtl_url = "/show"
    drop_breadcrumb({
                      :name => _("Cloud Volumes"),
                      :url  => "/cloud_volume/show_list?page=#{@current_page}&refresh=y"},
                    true)

    case @display
    when "download_pdf", "main", "summary_only"
      get_tagdata(@volume)
      drop_breadcrumb(
        :name => _("%{name} (Summary)") % {:name => @volume.name.to_s},
        :url  => "/cloud_volume/show/#{@volume.id}"
      )
      @showtype = "main"
      set_summary_pdf_data if %w(download_pdf summary_only).include?(@display)
    when "cloud_volume_snapshots"
      title = ui_lookup(:tables => 'cloud_volume_snapshots')
      kls   = CloudVolumeSnapshot
      drop_breadcrumb(
        :name => _("%{name} (All %{children})") % {:name => @volume.name, :children => title},
        :url  => "/cloud_volume/show/#{@volume.id}?display=cloud_volume_snapshots"
      )
      @view, @pages = get_view(kls, :parent => @volume, :association => :cloud_volume_snapshots)
      @showtype = @display
    when "instances"
      title = ui_lookup(:tables => "vm_cloud")
      kls   = ManageIQ::Providers::CloudManager::Vm
      drop_breadcrumb(
        :name => _("%{name} (All %{title})") % {:name => @volume.name, :title => title},
        :url  => "/cloud_volume/show/#{@volume.id}?display=#{@display}"
      )
      @view, @pages = get_view(kls, :parent => @volume) # Get the records (into a view) and the paginator
      @showtype = @display
    end

    if params[:ppsetting] || params[:searchtag] || params[:entry] || params[:sort_choice]
      replace_gtl_main_div
    end
  end

  # Show the main Cloud Volume list view
  def show_list
    process_show_list
  end

  def cloud_volume_form_fields
    assert_privileges("cloud_volume_edit")
    volume = find_by_id_filtered(CloudVolume, params[:id])
    render :json => {
      :name => volume.name
    }
  end

  def attach
    assert_privileges("cloud_volume_attach")
    @vm_choices = {}
    @volume = find_by_id_filtered(CloudVolume, params[:id])
    @volume.cloud_tenant.vms.each { |vm| @vm_choices[vm.name] = vm.id }

    @in_a_form = true
    drop_breadcrumb(
      :name => _("Attach %{model} \"%{name}\"") % {
        :model => ui_lookup(:table => 'cloud_volume'),
        :name  => @volume.name
      },
      :url  => "/cloud_volume/attach")
  end

  def detach
    assert_privileges("cloud_volume_detach")
    @volume = find_by_id_filtered(CloudVolume, params[:id])
    @vm_choices = @volume.vms.each_with_object({}) { |vm, hash| hash[vm.name] = vm.id }

    @in_a_form = true
    drop_breadcrumb(
      :name => _("Detach %{model} \"%{name}\"") % {
        :model => ui_lookup(:table => 'cloud_volume'),
        :name  => @volume.name
      },
      :url  => "/cloud_volume/detach")
  end

  def cancel_action(message)
    session[:edit] = nil
    @breadcrumbs.pop if @breadcrumbs
    javascript_redirect :action    => @lastaction,
                        :id        => @volume.id,
                        :display   => session[:cloud_volume_display],
                        :flash_msg => message
  end

  def attach_volume
    assert_privileges("cloud_volume_attach")

    @volume = find_by_id_filtered(CloudVolume, params[:id])
    case params[:button]
    when "cancel"
      cancel_action(_("Attaching %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'cloud_volume'),
        :name  => @volume.name
      })
    when "attach"
      options = form_params
      vm = find_by_id_filtered(VmCloud, options[:vm_id])
      if @volume.is_available?(:attach_volume)
        begin
          @volume.raw_attach_volume(vm.ems_ref, options['device_path'])
          add_flash(_("Attaching %{volume} \"%{volume_name}\" to %{vm_name}") % {
            :volume      => ui_lookup(:table => 'cloud_volume'),
            :volume_name => @volume.name,
            :vm_name     => vm.name})
        rescue => ex
          add_flash(_("Unable to attach %{volume} \"%{volume_name}\" to %{vm_name}: %{details}") % {
            :volume      => ui_lookup(:table => 'cloud_volume'),
            :volume_name => @volume.name,
            :vm_name     => vm.name,
            :details     => get_error_message_from_fog(ex)}, :error)
        end
      else
        add_flash(_(volume.is_available_now_error_message(:attach_volume)), :error)
      end
      @breadcrumbs.pop if @breadcrumbs
      session[:edit] = nil
      session[:flash_msgs] = @flash_array.dup if @flash_array
      javascript_redirect :action => "show", :id => @volume.id.to_s
    end
  end

  def detach_volume
    assert_privileges("cloud_volume_detach")

    @volume = find_by_id_filtered(CloudVolume, params[:id])
    case params[:button]
    when "cancel"
      cancel_action(_("Detaching %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'cloud_volume'),
        :name  => @volume.name
      })

    when "detach"
      options = form_params
      vm = find_by_id_filtered(VmCloud, options[:vm_id])
      if @volume.is_available?(:detach_volume)
        begin
          @volume.raw_detach_volume(vm.ems_ref)
          add_flash(_("Detaching %{volume} \"%{volume_name}\" from %{vm_name}") % {
            :volume      => ui_lookup(:table => 'cloud_volume'),
            :volume_name => @volume.name,
            :vm_name     => vm.name})
        rescue => ex
          add_flash(_("Unable to detach %{volume} \"%{volume_name}\" from %{vm_name}: %{details}") % {
            :volume      => ui_lookup(:table => 'cloud_volume'),
            :volume_name => @volume.name,
            :vm_name     => vm.name,
            :details     => get_error_message_from_fog(ex)}, :error)
        end
      else
        add_flash(_(volume.is_available_now_error_message(:detach_volume)), :error)
      end
      @breadcrumbs.pop if @breadcrumbs
      session[:edit] = nil
      session[:flash_msgs] = @flash_array.dup if @flash_array
      javascript_redirect :action => "show", :id => @volume.id.to_s
    end
  end

  def new
    assert_privileges("cloud_volume_new")
    @volume = CloudVolume.new
    @in_a_form = true
    @cloud_tenant_choices = {}
    CloudTenant.all.each { |tenant| @cloud_tenant_choices[tenant.name] = tenant.id }
    drop_breadcrumb(
      :name => _("Add New %{model}") % {:model => ui_lookup(:table => 'cloud_volume')},
      :url  => "/cloud_volume/new"
    )
  end

  def create
    assert_privileges("cloud_volume_new")
    case params[:button]
    when "cancel"
      javascript_redirect :action => 'show_list',
                          :flash_msg => _("Add of new %{model} was cancelled by the user") % {:model => ui_lookup(:table => 'cloud_volume')}

    when "add"
      @volume = CloudVolume.new
      options = form_params
      cloud_tenant = find_by_id_filtered(CloudTenant, options[:cloud_tenant_id])
      valid_action, action_details = CloudVolume.validate_create_volume(cloud_tenant.ext_management_system)
      if valid_action
        begin
          CloudVolume.create_volume(cloud_tenant.ext_management_system, options)
          add_flash(_("Creating %{volume} \"%{volume_name}\"") % {
            :volume      => ui_lookup(:table => 'cloud_volume'),
            :volume_name => options[:name]})
        rescue => ex
          add_flash(_("Unable to create %{volume} \"%{volume_name}\": %{details}") % {
            :volume      => ui_lookup(:table => 'cloud_volume'),
            :volume_name => options[:name],
            :details     => ex}, :error)
        end
        @breadcrumbs.pop if @breadcrumbs
        session[:flash_msgs] = @flash_array.dup if @flash_array
        javascript_redirect :action => "show_list"
      else
        @in_a_form = true
        add_flash(_(action_details), :error) unless action_details.nil?
        drop_breadcrumb(
          :name => _("Add New %{model}") % {:model => ui_lookup(:table => 'cloud_volume')},
          :url  => "/cloud_volume/new"
        )
        javascript_flash
      end

    when "validate"
      @in_a_form = true
      options = form_params
      cloud_tenant = find_by_id_filtered(CloudTenant, options[:cloud_tenant_id])
      valid_action, action_details = CloudVolume.validate_create_volume(cloud_tenant.ext_management_system)
      if valid_action
        add_flash(_("Validation successful"))
      else
        add_flash(_(action_details), :error) unless details.nil?
      end
      javascript_flash
    end
  end

  def edit
    assert_privileges("cloud_volume_edit")
    @volume = find_by_id_filtered(CloudVolume, params[:id])
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Edit %{model} \"%{name}\"") % {:model => ui_lookup(:table => 'cloud_volume'), :name => @volume.name},
      :url  => "/cloud_volume/edit/#{@volume.id}"
    )
  end

  def update
    assert_privileges("cloud_volume_edit")
    @volume = find_by_id_filtered(CloudVolume, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'cloud_volume'),
        :name  => @volume.name
      })

    when "save"
      options = form_params
      valid_update, update_details = @volume.validate_update_volume
      if valid_update
        begin
          @volume.update_volume(options)
          add_flash(_("Updating %{model} \"%{name}\"") % {
            :model => ui_lookup(:table => 'cloud_volume'),
            :name  => @volume.name
          })
        rescue => ex
          add_flash(_("Unable to update %{model} \"%{name}\": %{details}") % {
            :model   => ui_lookup(:table => 'cloud_volume'),
            :name    => @volume.name,
            :details => ex
          }, :error)
        end
      else
        add_flash(_(update_details), :error)
      end
      @breadcrumbs.pop if @breadcrumbs
      session[:edit] = nil
      session[:flash_msgs] = @flash_array.dup if @flash_array
      javascript_redirect :action => "show", :id => @volume.id

    when "validate"
      @in_a_form = true
      options = form_params
      cloud_tenant = find_by_id_filtered(CloudTenant, options[:cloud_tenant_id])
      valid_action, action_details = CloudVolume.validate_create_volume(cloud_tenant.ext_management_system)
      if valid_action
        add_flash(_("Validation successful"))
      else
        add_flash(_(action_details), :error) unless details.nil?
      end
      javascript_flash
    end
  end

  # delete selected volumes
  def delete_volumes
    assert_privileges("cloud_volume_delete")

    volumes = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "cloud_volume")
                find_checked_items
              else
                [params[:id]]
              end

    if volumes.empty?
      add_flash(_("No %{models} were selected for deletion.") % {
        :models => ui_lookup(:tables => "cloud_volume")
      }, :error)
    end

    volumes_to_delete = []
    volumes.each do |v|
      volume = CloudVolume.find_by_id(v)
      if volume.nil?
        add_flash(_("%{model} no longer exists.") % {:model => ui_lookup(:table => "cloud_volume")}, :error)
      elsif !volume.attachments.empty?
        add_flash(_("%{model} \"%{name}\" cannot be removed because it is attached to one or more %{instances}") % {
          :model     => ui_lookup(:table => 'cloud_volume'),
          :name      => volume.name,
          :instances => ui_lookup(:tables => 'vm_cloud')}, :warning)
      else
        valid_delete, delete_details = volume.validate_delete_volume
        if valid_delete
          volumes_to_delete.push(volume)
        else
          add_flash(_("Couldn't initiate deletion of %{model} \"%{name}\": %{details}") % {
            :model   => ui_lookup(:table => 'cloud_volume'),
            :name    => volume.name,
            :details => delete_details}, :error)
        end
      end
    end
    process_cloud_volumes(volumes_to_delete, "destroy") unless volumes_to_delete.empty?

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "cloud_volume"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected %{model} was deleted") % {:model => ui_lookup(:table => "cloud_volume")})
      end
    end
  end

  def backup_new
    assert_privileges("cloud_volume_backup_create")
    @volume = find_by_id_filtered(CloudVolume, params[:id])
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Create Backup for %{model} \"%{name}\"") % {:model => ui_lookup(:table => 'cloud_volume'), :name => @volume.name},
      :url  => "/cloud_volume/backup_new/#{@volume.id}"
    )
  end

  def backup_create
    assert_privileges("cloud_volume_backup_create")
    @volume = find_by_id_filtered(CloudVolume, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Backup of %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'cloud_volume'),
        :name  => @volume.name
      })

    when "create"
      options = {}
      options[:name] = params[:backup_name] if params[:backup_name]
      options[:incremental] = true if params[:incremental]
      begin
        @volume.backup_create(options)
        add_flash(_("Creating backup for %{model} \"%{name}\"") % {
          :model => ui_lookup(:table => 'cloud_volume'),
          :name  => @volume.name
        })
      rescue => ex
        add_flash(_("Unable to create backup for %{model} \"%{name}\": %{details}") % {
          :model   => ui_lookup(:table => 'cloud_volume'),
          :name    => @volume.name,
          :details => ex
        }, :error)
      end
    end
    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array
    javascript_redirect :action => "show", :id => @volume.id
  end

  def backup_select
    assert_privileges("cloud_volume_backup_restore")
    @volume = find_by_id_filtered(CloudVolume, params[:id])
    @backup_choices = {}
    @volume.cloud_volume_backups.each { |backup| @backup_choices[backup.name] = backup.id }
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Restore %{model} \"%{name}\" from a Backup") % {:model => ui_lookup(:table => 'cloud_volume'), :name => @volume.name},
      :url  => "/cloud_volume/backup_select/#{@volume.id}"
    )
  end

  def backup_restore
    assert_privileges("cloud_volume_backup_restore")
    @volume = find_by_id_filtered(CloudVolume, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Restore of %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'cloud_volume'),
        :name  => @volume.name
      })

    when "restore"
      begin
        @backup = find_by_id_filtered(CloudVolumeBackup, params[:backup_id])
        @volume.backup_restore(@backup.ems_ref)
        add_flash(_("Restoring %{model} \"%{name}\" from backup") % {
                    :model => ui_lookup(:table => 'cloud_volume'),
                    :name  => @volume.name
                  })
      rescue => ex
        add_flash(_("Unable to restore %{model} \"%{name}\" from backup: %{details}") % {
                    :model   => ui_lookup(:table => 'cloud_volume'),
                    :name    => @volume.name,
                    :details => ex
                  }, :error)
      end
    end
    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array
    javascript_redirect :action => "show", :id => @volume.id
  end

  private

  def form_params
    options = {}
    options[:name] = params[:name] if params[:name]
    options[:size] = params[:size].to_i if params[:size]
    options[:cloud_tenant_id] = params[:cloud_tenant_id] if params[:cloud_tenant_id]
    options[:vm_id] = params[:vm_id] if params[:vm_id]
    options[:device_path] = params[:device_path] if params[:device_path]
    options
  end

  # dispatches tasks to multiple volumes
  def process_cloud_volumes(volumes, task)
    return if volumes.empty?

    if task == "destroy"
      volumes.each do |volume|
        audit = {
          :event        => "cloud_volume_record_delete_initiateed",
          :message      => "[#{volume.name}] Record delete initiated",
          :target_id    => volume.id,
          :target_class => "CloudVolume",
          :userid       => session[:userid]
        }
        AuditEvent.success(audit)
        volume.delete_volume
      end
      add_flash(n_("Delete initiated for %{number} Cloud Volume.",
                   "Delete initiated for %{number} Cloud Volumes.",
                   volumes.length) % {:number => volumes.length})
    end
  end

  def get_session_data
    @title      = ui_lookup(:table => 'cloud_volume')
    @layout     = "cloud_volume"
    @lastaction = session[:cloud_volume_lastaction]
    @display    = session[:cloud_volume_display]
    @filters    = session[:cloud_volume_filters]
    @catinfo    = session[:cloud_volume_catinfo]
    @showtype   = session[:cloud_volume_showtype]
  end

  def set_session_data
    session[:cloud_volume_lastaction] = @lastaction
    session[:cloud_volume_display]    = @display unless @display.nil?
    session[:cloud_volume_filters]    = @filters
    session[:cloud_volume_catinfo]    = @catinfo
    session[:cloud_volume_showtype]   = @showtype
  end
end
