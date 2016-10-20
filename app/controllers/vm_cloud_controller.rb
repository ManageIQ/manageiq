class VmCloudController < ApplicationController
  include VmCommon # common methods for vm controllers
  include VmShowMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.table_name
    @table_name ||= "vm_cloud"
  end

  def attach
    assert_privileges("instance_attach")
    @volume_choices = {}
    @record = @vm = find_by_id_filtered(VmCloud, params[:id])
    @vm.cloud_tenant.cloud_volumes.each { |volume| @volume_choices[volume.name] = volume.id }

    @in_a_form = true
    drop_breadcrumb(
      :name => _("Attach %{volume} to %{instance_model} \"%{instance_name}\"") % {
        :volume         => ui_lookup(:table => 'cloud_volume'),
        :instance_model => ui_lookup(:table => 'vm_cloud'),
        :instance_name  => @vm.name
      },
      :url  => "/vm_cloud/attach")
    @in_a_form = true
    @refresh_partial = "vm_common/attach"
  end
  alias instance_attach attach

  def detach
    assert_privileges("instance_detach")
    @volume_choices = {}
    @record = @vm = find_by_id_filtered(VmCloud, params[:id])
    attached_volumes = @vm.hardware.disks.select(&:backing).map(&:backing)
    attached_volumes.each { |volume| @volume_choices[volume.name] = volume.id }
    if attached_volumes.empty?
      add_flash(_("%{instance_model} \"%{instance_name}\" has no attached %{volumes}") % {
        :volumes        => ui_lookup(:tables => 'cloud_volumes'),
        :instance_model => ui_lookup(:table => 'vm_cloud'),
        :instance_name  => @vm.name})
      javascript_flash
    end

    @in_a_form = true
    drop_breadcrumb(
      :name => _("Detach %{volume} from %{instance_model} \"%{instance_name}\"") % {
        :volume         => ui_lookup(:table => 'cloud_volume'),
        :instance_model => ui_lookup(:table => 'vm_cloud'),
        :instance_name  => @vm.name
      },
      :url  => "/vm_cloud/detach")
    @in_a_form = true
    @refresh_partial = "vm_common/detach"
  end
  alias instance_detach detach

  def attach_volume
    assert_privileges("instance_attach")

    @vm = find_by_id_filtered(VmCloud, params[:id])
    case params[:button]
    when "cancel"
      cancel_action(_("Attaching %{volume_model} to %{instance_model} \"%{instance_name}\" was cancelled by the user") % {
        :volume_model   => ui_lookup(:table => 'cloud_volume'),
        :instance_model => ui_lookup(:table => 'vm_cloud'),
        :instance_name  => @vm.name
      })
    when "attach"
      volume = find_by_id_filtered(CloudVolume, params[:volume_id])
      if volume.is_available?(:attach_volume)
        begin
          volume.raw_attach_volume(@vm.ems_ref, params[:device_path])
          add_flash(_("Attaching %{volume} \"%{volume_name}\" to %{vm_name}") % {
            :volume      => ui_lookup(:table => 'cloud_volume'),
            :volume_name => volume.name,
            :vm_name     => @vm.name})
        rescue => ex
          add_flash(_("Unable to attach %{volume} \"%{volume_name}\" to %{vm_name}: %{details}") % {
            :volume      => ui_lookup(:table => 'cloud_volume'),
            :volume_name => volume.name,
            :vm_name     => @vm.name,
            :details     => get_error_message_from_fog(ex)}, :error)
        end
      else
        add_flash(_(volume.is_available_now_error_message(:attach_volume)), :error)
      end
      @breadcrumbs.pop if @breadcrumbs
      session[:edit] = nil
      @record = @sb[:action] = nil
      replace_right_cell

    end
  end

  def detach_volume
    assert_privileges("instance_detach")

    @vm = find_by_id_filtered(VmCloud, params[:id])
    case params[:button]
    when "cancel"
      cancel_action(_("Detaching a %{volume} from %{instance_model} \"%{instance_name}\" was cancelled by the user") % {
        :volume         => ui_lookup(:table => 'cloud_volume'),
        :instance_model => ui_lookup(:table => 'vm_cloud'),
        :instance_name  => @vm.name
      })

    when "detach"
      volume = find_by_id_filtered(CloudVolume, params[:volume_id])
      if volume.is_available?(:detach_volume)
        begin
          volume.raw_detach_volume(@vm.ems_ref)
          add_flash(_("Detaching %{volume} \"%{volume_name}\" from %{vm_name}") % {
            :volume      => ui_lookup(:table => 'cloud_volume'),
            :volume_name => volume.name,
            :vm_name     => @vm.name})
        rescue => ex
          add_flash(_("Unable to detach %{volume} \"%{volume_name}\" from %{vm_name}: %{details}") % {
            :volume      => ui_lookup(:table => 'cloud_volume'),
            :volume_name => volume.name,
            :vm_name     => @vm.name,
            :details     => get_error_message_from_fog(ex)}, :error)
        end
      else
        add_flash(_(volume.is_available_now_error_message(:detach_volume)), :error)
      end
      @breadcrumbs.pop if @breadcrumbs
      session[:edit] = nil
      @record = @sb[:action] = nil
      replace_right_cell
    end
  end

  def cancel_action(message)
    session[:edit] = nil
    add_flash(message)
    @record = @sb[:action] = nil
    replace_right_cell
  end

  private

  def features
    [
      ApplicationController::Feature.new_with_hash(
        :role  => "instances_accord",
        :name  => :instances,
        :title => _("Instances by Provider")),

      ApplicationController::Feature.new_with_hash(
        :role  => "images_accord",
        :name  => :images,
        :title => _("Images by Provider")),

      ApplicationController::Feature.new_with_hash(
        :role  => "instances_filter_accord",
        :name  => :instances_filter,
        :title => _("Instances"),),

      ApplicationController::Feature.new_with_hash(
        :role  => "images_filter_accord",
        :name  => :images_filter,
        :title => _("Images"),)
    ]
  end

  # redefine get_filters from VmShow
  def get_filters
    session[:instances_filters]
  end

  def prefix_by_nodetype(nodetype)
    case TreeBuilder.get_model_for_prefix(nodetype).underscore
    when "miq_template" then "images"
    when "vm"           then "instances"
    end
  end

  def set_elements_and_redirect_unauthorized_user
    @nodetype, id = parse_nodetype_and_id(params[:id])
    prefix = prefix_by_nodetype(@nodetype)

    # Position in tree that matches selected record
    if role_allows?(:feature => "instances_accord") && prefix == "instances"
      set_active_elements_authorized_user('instances_tree', 'instances', true, ManageIQ::Providers::CloudManager::Vm, id)
    elsif role_allows?(:feature => "images_accord") && prefix == "images"
      set_active_elements_authorized_user('images_tree', 'images', true, ManageIQ::Providers::CloudManager::Template, id)
    elsif role_allows?(:feature => "#{prefix}_filter_accord")
      set_active_elements_authorized_user("#{prefix}_filter_tree", "#{prefix}_filter", false, nil, nil)
    else
      if (prefix == "vms" && role_allows?(:feature => "vms_instances_filter_accord")) ||
         (prefix == "templates" && role_allows?(:feature => "templates_images_filter_accord"))
        redirect_to(:controller => 'vm_or_template', :action => "explorer", :id => params[:id])
      else
        redirect_to(:controller => 'dashboard', :action => "auth_error")
      end
      return true
    end

    resolve_node_info(params[:id])
  end

  def tagging_explorer_controller?
    @explorer
  end

  def skip_breadcrumb?
    breadcrumb_prohibited_for_action?
  end
end
