class CloudSubnetController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericButtonMixin
  include Mixins::GenericListMixin
  include Mixins::GenericSessionMixin
  include Mixins::GenericShowMixin
  include Mixins::CheckedIdMixin
  include Mixins::GenericFormMixin

  def self.display_methods
    %w(instances cloud_subnets)
  end

  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:display] = @display if %w(vms instances images).include?(@display)
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh

    @refresh_div = "main_div"

    case params[:pressed]
    when "cloud_subnet_tag"
      return tag("CloudSubnet")
    when 'cloud_subnet_delete'
      delete_subnets
    when "cloud_subnet_edit"
      javascript_redirect :action => "edit", :id => checked_item_id
    else
      if params[:pressed] == "cloud_subnet_new"
        javascript_redirect :action => "new"
      elsif !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  def cloud_subnet_form_fields
    assert_privileges("cloud_subnet_edit")
    subnet = find_by_id_filtered(CloudSubnet, params[:id])
    render :json => {
      :name         => subnet.name,
      :cidr         => subnet.cidr,
      :dhcp_enabled => subnet.dhcp_enabled,
      :gateway      => subnet.gateway,
      :ip_version   => subnet.ip_version,
    }
  end

  def new
    assert_privileges("cloud_subnet_new")
    @subnet = CloudSubnet.new
    @in_a_form = true
    @network_provider_choices = {}
    ExtManagementSystem.where(:type => "ManageIQ::Providers::Openstack::NetworkManager").find_each { |ems| @network_provider_choices[ems.name] = ems.id }
    # TODO: (gildub) Replace with angular lookup to narrow choice dynamically
    @network_choices = {}
    CloudNetwork.all.each { |network| @network_choices[network.name] = network.ems_ref }
    @cloud_tenant_choices = {}
    CloudTenant.all.each { |tenant| @cloud_tenant_choices[tenant.name] = tenant.id }
    drop_breadcrumb(
      :name => _("Add New Subnet"),
      :url  => "/cloud_subnet/new"
    )
  end

  def create
    assert_privileges("cloud_subnet_new")
    case params[:button]
    when "cancel"
      javascript_redirect :action    => 'show_list',
                          :flash_msg => _("Creation of a Cloud Subnet was cancelled by the user")

    when "add"
      @subnet = CloudSubnet.new
      options = new_form_params
      ems = ExtManagementSystem.find(options[:ems_id])
      options.delete(:ems_id)
      task_id = ems.create_cloud_subnet_queue(session[:userid], options)

      if task_id.kind_of?(Integer)
        initiate_wait_for_task(:task_id => task_id, :action => "create_finished")
      else
        javascript_flash(
          :text        => _("Cloud Subnet creation: Task start failed: ID [%{id}]") % {:id => task_id.to_s},
          :severity    => :error,
          :spinner_off => true
        )
      end
    end
  end

  def create_finished
    task_id = session[:async][:params][:task_id]
    subnet_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Cloud Subnet \"%{name}\" created") % { :name  => subnet_name })
    else
      add_flash(_("Unable to create Cloud Subnet: %{details}") %
                { :name => subnet_name, :details => task.message }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array
    javascript_redirect :action => "show_list"
  end

  def delete_subnets
    assert_privileges("cloud_subnet_delete")

    subnets = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "cloud_subnet") || @lastaction.nil?
                find_checked_items
              else
                [params[:id]]
              end

    if subnets.empty?
      add_flash(_("No Cloud Subnet were selected for deletion."), :error)
    end

    subnets_to_delete = []
    subnets.each do |s|
      subnet = CloudSubnet.find_by_id(s)
      if subnet.nil?
        add_flash(_("Cloud Subnet no longer exists."), :error)
      elsif subnet.supports_delete?
        subnets_to_delete.push(subnet)
      end
    end
    unless subnets_to_delete.empty?
      process_cloud_subnets(subnets_to_delete, "destroy")
    end

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "cloud_subnet"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected Cloud Subnet was deleted"))
      end
      javascript_redirect :action => 'show_list', :flash_msg => @flash_array[0][:message]
    else
      drop_breadcrumb(:name => 'dummy', :url  => " ") # missing a bc to get correctly back so here's a dummy
      session[:flash_msgs] = @flash_array.dup if @flash_array
      redirect_to(previous_breadcrumb_url)
    end
  end

  def edit
    params[:id] = checked_item_id unless params[:id].present?
    assert_privileges("cloud_subnet_edit")
    @subnet = find_by_id_filtered(CloudSubnet, params[:id])
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Edit Subnet \"%{name}\"") % {:name => @subnet.name},
      :url  => "/cloud_subnet/edit/#{@subnet.id}"
    )
  end

  def update
    assert_privileges("cloud_subnet_edit")
    @subnet = find_by_id_filtered(CloudSubnet, params[:id])
    options = changed_form_params
    case params[:button]
    when "cancel"
      cancel_action(_("Edit of Subnet \"%{name}\" was cancelled by the user") % {:name  => @subnet.name})

    when "save"
      task_id = @subnet.update_cloud_subnet_queue(session[:userid], options)

      if task_id.kind_of?(Integer)
        initiate_wait_for_task(:task_id => task_id, :action => "update_finished")
      else
        javascript_flash(
          :text        => _("Cloud Subnet update failed: Task start failed: ID [%{id}]") % {:id => task_id.to_s},
          :severity    => :error,
          :spinner_off => true
        )
      end
    end
  end

  def update_finished
    task_id = session[:async][:params][:task_id]
    subnet_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Cloud Subnet \"%{name}\" updated") % {:name  => subnet_name })
    else
      add_flash(
        _("Unable to update Cloud Subnet \"%{name}\": %{details}") % { :name    => subnet_name,
                                                                       :details => task.message }, :error)
    end

    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array
    javascript_redirect previous_breadcrumb_url
  end

  private

  def switch_to_bol(option)
    if option && option =~ /on|true/i
      true
    else
      false
    end
  end

  def changed_form_params
    # Fields allowed for update are: name, enable_dhcp, dns_nameservers, allocation_pools, host_routes, gateway_ip
    options = {}
    options[:name] = params[:name] unless @subnet.name == params[:name]

    # A gateway address is automatically assigned by Openstack when gateway is null
    unless @subnet.gateway == params[:gateway]
      options[:gateway_ip] = params[:gateway].empty? ? nil : params[:gateway]
    end
    unless @subnet.dhcp_enabled == switch_to_bol(params[:dhcp_enabled])
      options[:enable_dhcp] = switch_to_bol(params[:dhcp_enabled])
    end
    # TODO: Add dns_nameservers, allocation_pools, host_routes
    options
  end

  def new_form_params
    params[:ip_version] ||= "4"
    params[:dhcp_enabled] ||= false
    options = {}
    options[:name] = params[:name] if params[:name]
    options[:ems_id] = params[:ems_id] if params[:ems_id]
    options[:cidr] = params[:cidr] if params[:cidr]
    # An address is automatically assigned by Openstack when gateway is null
    if params[:gateway]
      options[:gateway] = params[:gateway].empty? ? nil : params[:gateway]
    end
    options[:ip_version] = params[:ip_version]
    options[:cloud_tenant] = find_by_id_filtered(CloudTenant, params[:cloud_tenant_id]) if params[:cloud_tenant_id]
    options[:network_id] = params[:network_id] if params[:network_id]
    options[:enable_dhcp] = params[:dhcp_enabled]
    # TODO: Add extra fields
    options[:availability_zone_id] = params[:availability_zone_id] if params[:availability_zone_id]
    if params[:ipv6_router_advertisement_mode]
      options[:ipv6_router_advertisement_mode] = params[:ipv6_router_advertisement_mode]
    end
    options[:ipv6_address_mode] = params[:ipv6_address_mode] if params[:ipv6_address_mode]
    options[:network_group_id] = params[:network_group_id] if params[:network_group_id]
    options[:parent_cloud_subnet_id] = params[:parent_cloud_subnet_id] if params[:parent_cloud_subnet_id]
    options
  end

  # dispatches operations to multiple subnets
  def process_cloud_subnets(subnets, operation)
    return if subnets.empty?

    if operation == "destroy"
      deleted_subnets = 0
      subnets.each do |subnet|
        audit = {
          :event        => "cloud_subnet_record_delete_initiated",
          :message      => "[#{subnet.name}] Record delete initiated",
          :target_id    => subnet.id,
          :target_class => "CloudSubnet",
          :userid       => session[:userid]
        }
        AuditEvent.success(audit)
        subnet.delete_cloud_subnet_queue(session[:userid])
      end
    end
  end

  menu_section :net
end
