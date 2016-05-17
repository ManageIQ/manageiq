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

  def resize
    assert_privileges("instance_resize")
    @record = find_by_id_filtered(VmOrTemplate, params[:id]) # Set the VM object
    drop_breadcrumb(
      :name => _("Reconfigure Instance '%{name}'") % {:name => @record.name},
      :url  => "/vm_cloud/resize"
    ) unless @explorer
    @flavors = {}
    unless @record.ext_management_system.nil?
      @record.ext_management_system.flavors.each { |f| @flavors[f.name] = f.id unless f == @record.flavor }
    end
    @edit = {}
    @edit[:new] ||= {}
    unless @record.flavor.nil?
      @edit[:new][:flavor] = @record.flavor.id
    end
    @edit[:key] = "vm_resize__#{@record.id}"
    @edit[:vm_id] = @record.id
    @edit[:explorer] = true if params[:action] == "x_button" || session.fetch_path(:edit, :explorer)
    session[:edit] = @edit
    @in_a_form = true
    @refresh_partial = "vm_common/resize"
  end
  alias instance_resize resize

  def resize_vm
    assert_privileges("instance_resize")
    load_edit("vm_resize__#{params[:id]}")
    flavor_id = @edit[:new][:flavor]
    flavor = find_by_id_filtered(Flavor, flavor_id)
    @record = VmOrTemplate.find_by_id(params[:id])

    case params[:button]
    when "cancel"
      add_flash(_("Reconfigure of %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => "vm_cloud"), :name => @record.name})
      @record = @sb[:action] = nil
      replace_right_cell
    when "submit"
      valid, details = @record.validate_resize
      if valid
        begin
          old_flavor = @record.flavor
          @record.resize(flavor)
          add_flash(_("Reconfiguring %{instance} \"%{name}\" from %{old_flavor} %{new_flavor}") % {
            :instance   => ui_lookup(:table => 'vm_cloud'),
            :name       => @record.name,
            :old_flavor => old_flavor.name,
            :new_flavor => flavor.name})
        rescue => ex
          add_flash(_("Unable to reconfigure %{instance} \"%{name}\": %{details}") % {
            :instance => ui_lookup(:table => 'vm_cloud'),
            :name     => @record.name,
            :details  => ex}, :error)
        end
      else
        add_flash(_("Unable to reconfigure %{instance} \"%{name}\": %{details}") % {
          :instance => ui_lookup(:table => 'vm_cloud'),
          :name     => @record.name,
          :details  => details}, :error)
      end
      params[:id] = @record.id.to_s # reset id in params for show
      @record = nil
      @sb[:action] = nil
      replace_right_cell
    end
  end

  def resize_field_changed
    return unless load_edit("vm_resize__#{params[:id]}")
    @edit ||= {}
    @edit[:new] ||= {}
    @edit[:new][:flavor] = params[:flavor]
    render :update do |page|
      page << javascript_prologue
      page.replace_html("main_div",
                        :partial => "vm_common/resize") if %w(allright left right).include?(params[:button])
      page << javascript_for_miq_button_visibility(true)
      page << "miqSparkle(false);"
    end
  end

  def live_migrate
    assert_privileges("instance_live_migrate")
    @record = find_by_id_filtered(VmOrTemplate, params[:id]) # Set the VM object
    drop_breadcrumb(
      :name => _("Live Migrate Instance '%{name}'") % {:name => @record.name},
      :url  => "/vm_cloud/live_migrate"
    ) unless @explorer

    @edit = {}
    @edit[:key] = "vm_migrate__#{@record.id}"
    @edit[:vm_id] = @record.id
    @edit[:explorer] = true if params[:action] == "x_button" || session.fetch_path(:edit, :explorer)
    session[:edit] = @edit
    @in_a_form = true
    @refresh_partial = "vm_common/live_migrate"
  end
  alias_method :instance_live_migrate, :live_migrate

  def live_migrate_form_fields
    assert_privileges("instance_live_migrate")
    @record = find_by_id_filtered(VmOrTemplate, params[:id])
    clusters = []
    hosts = []
    @record.ext_management_system.find_filtered_children("ems_clusters").each do |c|
      clusters << {:id => c.id, :name => c.name}
    end
    @record.ext_management_system.find_filtered_children("hosts").each do |h|
      hosts << {:id => h.id, :name => h.name, :cluster_id => h.emd_cluster.id}
    end
    clusters.sort
    hosts.sort
    render :json => {
      :clusters => clusters,
      :hosts    => hosts
    }
  end

  def live_migrate_vm
    assert_privileges("instance_live_migrate")
    @record = find_by_id_filtered(VmOrTemplate, params[:id])

    case params[:button]
    when "cancel"
      add_flash(_("Live Migration of %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => "vm_cloud"), :name => @record.name})
      session[:flash_msgs] = @flash_array.dup
      render :update do |page|
        page.redirect_to(previous_breadcrumb_url)
      end
    when "submit"
      valid, details = @record.validate_live_migrate
      if valid
        if params['auto_select_host'] == '1'
          hostname = nil
        else
          hostname = find_by_filtered_id(Host, params[:destination_host_id]).hostname
          block_migration = @params[:block_migration]
          disk_over_commit = @params[:disk_over_commit]
        end
        begin
          @record.live_migrate(
            :hostname         => hostname,
            :block_migration  => block_migration == '1',
            :disk_over_commit => disk_over_commit == '1'
          )
          add_flash(_("Live Migrating %{instance} \"%{name}\"") % {
            :instance => ui_lookup(:table => 'vm_cloud'),
            :name     => @record.name})
        rescue => ex
          add_flash(_("Unable to live migrate %{instance} \"%{name}\": %{details}") % {
            :instance => ui_lookup(:table => 'vm_cloud'),
            :name     => @record.name,
            :details  => ex}, :error)
        end
      else
        add_flash(_("Unable to live migrate %{instance} \"%{name}\": %{details}") % {
          :instance => ui_lookup(:table => 'vm_cloud'),
          :name     => @record.name,
          :details  => details}, :error)
      end
      params[:id] = @record.id.to_s # reset id in params for show
      @record = nil
      @sb[:action] = nil
      replace_right_cell
    end
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
    @nodetype, id = params[:id].split("_").last.split("-")
    prefix = prefix_by_nodetype(@nodetype)

    # Position in tree that matches selected record
    if role_allows(:feature => "instances_accord") && prefix == "instances"
      set_active_elements_authorized_user('instances_tree', 'instances', true, ManageIQ::Providers::CloudManager::Vm, id)
    elsif role_allows(:feature => "images_accord") && prefix == "images"
      set_active_elements_authorized_user('images_tree', 'images', true, ManageIQ::Providers::CloudManager::Template, id)
    elsif role_allows(:feature => "#{prefix}_filter_accord")
      set_active_elements_authorized_user("#{prefix}_filter_tree", "#{prefix}_filter", false, nil, nil)
    else
      if (prefix == "vms" && role_allows(:feature => "vms_instances_filter_accord")) ||
         (prefix == "templates" && role_allows(:feature => "templates_images_filter_accord"))
        redirect_to(:controller => 'vm_or_template', :action => "explorer", :id => params[:id])
      else
        redirect_to(:controller => 'dashboard', :action => "auth_error")
      end
      return true
    end
    nodetype, id = params[:id].split("-")
    self.x_node = "#{nodetype}-#{to_cid(id)}"
    get_node_info(x_node)
  end

  def tagging_explorer_controller?
    @explorer
  end

  def skip_breadcrumb?
    breadcrumb_prohibited_for_action?
  end
end
