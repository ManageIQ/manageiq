module ApplicationController::VmCloudProcessing
  extend ActiveSupport::Concern

  def live_migrate
    assert_privileges("instance_live_migrate")
    @display = params[:display]

    ids = find_checked_items
    if !ids.empty?
      record_id = ids[0]
    else
      record_id = params[:id]
    end

    @record = find_by_id_filtered(VmOrTemplate, record_id) # Set the VM object
    if @record.is_available?(:live_migrate) && !@record.ext_management_system.nil?
      drop_breadcrumb(
        :name => _("Live Migrate Instance '%{name}'") % {:name => @record.name},
        :url  => "/vm_cloud/live_migrate"
      ) unless @explorer
      @in_a_form = true
      @refresh_partial = "vm_common/live_migrate"
    else
      add_flash(_("Unable to live migrate %{instance} \"%{name}\": %{details}") % {
        :instance => ui_lookup(:table => 'vm_cloud'),
        :name     => @record.name,
        :details  => @record.is_available_now_error_message(:live_migrate)}, :error)
    end
  end
  alias_method :instance_live_migrate, :live_migrate

  def live_migrate_form_fields
    assert_privileges("instance_live_migrate")
    @record = find_by_id_filtered(VmOrTemplate, params[:id])
    hosts = []
    unless @record.ext_management_system.nil?
      # wrap in a rescue block in the event the connection to the provider fails
      begin
        connection = @record.ext_management_system.connect
        current_hostname = connection.handled_list(:servers).find do |s|
          s.name == @record.name
        end.os_ext_srv_attr_hypervisor_hostname
        # OS requires its own name for the host be used in the migrate API, so get the
        # provider hostname from fog.
        hosts = connection.hosts.select { |h| h.service_name == "compute" && h.host_name != current_hostname }.map do |h|
          {:name => h.host_name, :id => h.host_name}
        end
      rescue
        hosts = []
      end
    end
    render :json => {
      :hosts => hosts
    }
  end

  def live_migrate_vm
    assert_privileges("instance_live_migrate")
    @record = find_by_id_filtered(VmOrTemplate, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Live Migration of %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'vm_cloud'),
        :name  => @record.name
      })
    when "submit"
      if @record.is_available?(:live_migrate)
        if params['auto_select_host'] == 'on'
          hostname = nil
        else
          hostname = params[:destination_host]
        end
        block_migration = params[:block_migration]
        disk_over_commit = params[:disk_over_commit]
        begin
          @record.live_migrate(
            :hostname         => hostname,
            :block_migration  => block_migration == 'on',
            :disk_over_commit => disk_over_commit == 'on'
          )
          add_flash(_("Live Migrating %{instance} \"%{name}\"") % {
            :instance => ui_lookup(:table => 'vm_cloud'),
            :name     => @record.name})
        rescue => ex
          add_flash(_("Unable to live migrate %{instance} \"%{name}\": %{details}") % {
            :instance => ui_lookup(:table => 'vm_cloud'),
            :name     => @record.name,
            :details  => get_error_message_from_fog(ex.to_s)}, :error)
        end
      else
        add_flash(_("Unable to live migrate %{instance} \"%{name}\": %{details}") % {
          :instance => ui_lookup(:table => 'vm_cloud'),
          :name     => @record.name,
          :details  => @record.is_available_now_error_message(:live_migrate)}, :error)
      end
      if @explorer
        params[:id] = @record.id.to_s # reset id in params for show
        @record = nil
        @sb[:action] = nil
        replace_right_cell
      else
        @breadcrumbs.pop if @breadcrumbs
        session[:edit] = nil
        session[:flash_msgs] = @flash_array.dup if @flash_array
        render :update do |page|
          page << javascript_prologue
          page.redirect_to :action => "show", :id => @record.id.to_s
        end
      end
    end
  end

  def cancel_action(message)
    if @explorer
      session[:edit] = nil
      add_flash(message)
      @record = @sb[:action] = nil
      replace_right_cell
    else
      @breadcrumbs.pop if @breadcrumbs
      render :update do |page|
        page << javascript_prologue
        page.redirect_to :action    => @lastaction,
                         :id        => @record.id,
                         :display   => @display,
                         :flash_msg => message
      end
    end
  end
end
