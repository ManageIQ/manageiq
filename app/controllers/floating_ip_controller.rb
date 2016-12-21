class FloatingIpController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::CheckedIdMixin
  include Mixins::GenericButtonMixin
  include Mixins::GenericListMixin
  include Mixins::GenericSessionMixin
  include Mixins::GenericShowMixin

  def self.display_methods
    %w()
  end

  menu_section :net

  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:display] = @display if %w(vms instances images).include?(@display)
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh

    @refresh_div = "main_div"

    case params[:pressed]
    when "floating_ip_tag"
      tag("FloatingIp")
    when 'floating_ip_delete'
      delete_floating_ips
    when "floating_ip_edit"
      javascript_redirect :action => "edit", :id => checked_item_id(params)
    when "floating_ip_new"
      javascript_redirect :action => "new"
    else
      if !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  def cancel_action(message)
    session[:edit] = nil
    @breadcrumbs.pop if @breadcrumbs
    javascript_redirect :action    => @lastaction,
                        :id        => @floating_ip.id,
                        :display   => session[:floating_ip_display],
                        :flash_msg => message
  end

  def create
    assert_privileges("floating_ip_new")
    case params[:button]
    when "cancel"
      javascript_redirect :action    => 'show_list',
                          :flash_msg => _("Add of new Floating IP was cancelled by the user")
    when "add"
      @floating_ip = FloatingIp.new
      options = form_params
      ems = ExtManagementSystem.find(options[:ems_id])
      options.delete(:ems_id)
      task_id = ems.create_floating_ip_queue(session[:userid], options)

      add_flash(_("Floating IP creation failed: Task start failed: ID [%{id}]") %
                {:id => task_id.to_s}, :error) unless task_id.kind_of?(Integer)

      if @flash_array
        javascript_flash(:spinner_off => true)
      else
        initiate_wait_for_task(:task_id => task_id, :action => "create_finished")
      end
    end
  end

  def create_finished
    task_id = session[:async][:params][:task_id]
    floating_ip_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Floating IP \"%{name}\" created") % { :name  => floating_ip_name })
    else
      add_flash(
        _("Unable to create Floating IP \"%{name}\": %{details}") % { :name    => floating_ip_name,
                                                                      :details => task.message }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show_list"
  end

  def delete_floating_ips
    assert_privileges("floating_ip_delete")

    floating_ips = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "floating_ip")
                     find_checked_items
                   else
                     [params[:id]]
                   end

    if floating_ips.empty?
      add_flash(_("No Floating IPs were selected for deletion."), :error)
    end

    floating_ips_to_delete = []
    floating_ips.each do |s|
      floating_ip = FloatingIp.find(s)
      if floating_ip.nil?
        add_flash(_("Floating IP no longer exists."), :error)
      else
        floating_ips_to_delete.push(floating_ip)
      end
    end
    process_floating_ips(floating_ips_to_delete, "destroy") unless floating_ips_to_delete.empty?

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "floating_ip"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected Floating IP was deleted"))
      else # or (if we deleted what we were showing) we redirect to the listing
        javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message]
      end
    end
  end

  def edit
    assert_privileges("floating_ip_edit")
    @floating_ip = find_by_id_filtered(FloatingIp, params[:id])
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Associate Floating IP \"%{name}\"") % { :name  => @floating_ip.name },
      :url  => "/floating_ip/edit/#{@floating_ip.id}")
  end

  def floating_ip_form_fields
    assert_privileges("floating_ip_edit")
    floating_ip = find_by_id_filtered(FloatingIp, params[:id])
    network_port_ems_ref = if floating_ip.network_port
                             floating_ip.network_port.ems_ref
                           else
                             ""
                           end
    # TODO: router field is missing!
    # :router_id            => floating_ip.router.id,
    render :json => {
      :fixed_ip_address     => floating_ip.fixed_ip_address,
      :floating_ip_address  => floating_ip.address,
      :cloud_network_name   => floating_ip.cloud_network.try(:name),
      :network_port_ems_ref => network_port_ems_ref,
      :cloud_tenant_name    => floating_ip.cloud_tenant.try(:name),
    }
  end

  def networks_by_ems
    assert_privileges("floating_ip_new")
    networks = []
    available_networks = CloudNetwork.where(:ems_id => params[:id], :external_facing => true).find_each
    available_networks.each do |network|
      networks << { 'name' => network.name, 'id' => network.id }
    end
    render :json => {
      :available_networks => networks
    }
  end

  def new
    assert_privileges("floating_ip_new")
    @floating_ip = FloatingIp.new
    @in_a_form = true
    @ems_choices = {}
    ExtManagementSystem.where(:type => "ManageIQ::Providers::Openstack::NetworkManager").find_each do |ems|
      @ems_choices[ems.name] = ems.id
    end
    @cloud_tenant_choices = {}
    CloudTenant.all.each { |tenant| @cloud_tenant_choices[tenant.name] = tenant.id }
    drop_breadcrumb(
      :name => _("Add New Floating IP"),
      :url  => "/floating_ip/new"
    )
  end

  def update
    assert_privileges("floating_ip_edit")
    @floating_ip = find_by_id_filtered(FloatingIp, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Edit of Floating IP \"%{name}\" was cancelled by the user") % { :name  => @floating_ip.name })

    when "save"
      options = form_params
      options.delete(:ems_id)
      task_id = @floating_ip.update_floating_ip_queue(session[:userid], options)

      add_flash(_("Floating IP update failed: Task start failed: ID [%{id}]") %
                {:id => task_id.to_s}, :error) unless task_id.kind_of?(Integer)

      if @flash_array
        javascript_flash(:spinner_off => true)
      else
        initiate_wait_for_task(:task_id => task_id, :action => "update_finished")
      end
    end
  end

  def update_finished
    task_id = session[:async][:params][:task_id]
    floating_ip_id = session[:async][:params][:id]
    floating_ip_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Floating IP \"%{name}\" updated") % { :name  => floating_ip_name })
    else
      add_flash(_("Unable to update Floating IP \"%{name}\": %{details}") % {
        :name    => floating_ip_name,
        :details => task.message }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show", :id => floating_ip_id
  end

  private

  def form_params
    options = {}
    options[:ems_id] = params[:ems_id] if params[:ems_id] && params[:ems_id] != 'new'
    options[:floating_ip_address] = params[:floating_ip_address] if params[:floating_ip_address]
    options[:cloud_network_id] = params[:cloud_network_id] if params[:cloud_network_id]
    options[:cloud_tenant] = find_by_id_filtered(CloudTenant, params[:cloud_tenant_id]) if params[:cloud_tenant_id]
    options[:network_port_ems_ref] = params[:network_port_ems_ref] if params[:network_port_ems_ref]
    options[:router_id] = params[:router_id] if params[:router_id]
    options
  end

  # dispatches operations to multiple floating_ips
  def process_floating_ips(floating_ips, operation)
    return if floating_ips.empty?

    if operation == "destroy"
      floating_ips.each do |floating_ip|
        audit = {
          :event        => "floating_ip_record_delete_initiated",
          :message      => "[#{floating_ip.name}] Record delete initiated",
          :target_id    => floating_ip.id,
          :target_class => "FloatingIp",
          :userid       => session[:userid]
        }
        AuditEvent.success(audit)
        floating_ip.delete_floating_ip_queue(session[:userid])
      end
      add_flash(n_("Delete initiated for %{number} Floating IP.",
                   "Delete initiated for %{number} Floating IPs.",
                   floating_ips.length) % {:number => floating_ips.length})
    end
  end
end
