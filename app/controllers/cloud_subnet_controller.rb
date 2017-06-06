class CloudSubnetController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericButtonMixin
  include Mixins::GenericListMixin
  include Mixins::GenericSessionMixin
  include Mixins::GenericShowMixin
  include Mixins::GenericFormMixin

  def self.display_methods
    %w(instances cloud_subnets)
  end

  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:display] = @display if %w(vms instances images).include?(@display)
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh

    @refresh_div = "main_div"
    return tag("CloudSubnet") if params[:pressed] == "cloud_subnet_tag"
    delete_subnets if params[:pressed] == 'cloud_subnet_delete'

    if params[:pressed] == "cloud_subnet_edit"
      checked_subnet_id = get_checked_subnet_id(params)
      javascript_redirect :action => "edit", :id => checked_subnet_id
    elsif params[:pressed] == "cloud_subnet_new"
      javascript_redirect :action => "new"
    elsif !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render_flash
    end
  end

  def cloud_subnet_form_fields
    assert_privileges("cloud_subnet_edit")
    subnet = find_record_with_rbac(CloudSubnet, params[:id])
    render :json => {
      :name       => subnet.name,
      :cidr       => subnet.cidr,
      :gateway    => subnet.gateway,
      :ip_version => subnet.ip_version
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
      :name => _("Add New Subnet") % {:model => ui_lookup(:table => 'cloud_subnet')},
      :url  => "/cloud_subnet/new"
    )
  end

  def create
    assert_privileges("cloud_subnet_new")
    case params[:button]
    when "cancel"
      javascript_redirect :action    => 'show_list',
                          :flash_msg => _("Add of new Subnet was cancelled by the user") % {:model => ui_lookup(:table => 'cloud_subnet')}

    when "add"
      @subnet = CloudSubnet.new
      options = form_params
      ems = ExtManagementSystem.find(options[:ems_id])
      if CloudSubnet.class_by_ems(ems).supports_create?
        begin
          CloudSubnet.create_subnet(ems, options)
          # TODO: To replace with targeted refresh when avail. or either use tasks
          EmsRefresh.queue_refresh(ManageIQ::Providers::NetworkManager)
          add_flash(_("Creating %{subnet} \"%{subnet_name}\"") % {
            :subnet      => ui_lookup(:table => 'cloud_subnet'),
            :subnet_name => options[:name]})
        rescue => ex
          add_flash(_("Unable to create %{subnet} \"%{subnet_name}\": %{details}") % {
            :subnet      => ui_lookup(:table => 'cloud_subnet'),
            :subnet_name => options[:name],
            :details     => ex}, :error)
        end
        @breadcrumbs.pop if @breadcrumbs
        session[:flash_msgs] = @flash_array.dup if @flash_array
        javascript_redirect :action => "show_list"
      else
        @in_a_form = true
        add_flash(_(CloudSubnet.unsupported_reason(:create)), :error)
        drop_breadcrumb(
          :name => _("Add New Subnet") % {:model => ui_lookup(:table => 'cloud_subnet')},
          :url  => "/cloud_subnet/new"
        )
        javascript_flash
      end
    end
  end

  def delete_subnets
    assert_privileges("cloud_subnet_delete")

    subnets = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "cloud_subnet") || @lastaction.nil?
                find_checked_items
              else
                [params[:id]]
              end

    if subnets.empty?
      add_flash(_("No subnet were selected for deletion.") % {
        :models => ui_lookup(:tables => "cloud_subnet")
      }, :error)
    end

    subnets_to_delete = []
    subnets.each do |s|
      subnet = CloudSubnet.find_by_id(s)
      if subnet.nil?
        add_flash(_("Subnet no longer exists.") % {:model => ui_lookup(:table => "cloud_subnet")}, :error)
      elsif subnet.supports_delete?
        subnets_to_delete.push(subnet)
      else
        add_flash(_("Couldn't initiate deletion of Subnet \"%{name}\": %{details}") % {
          :name    => subnet.name,
          :details => subnet.unsupported_reason(:delete)
        }, :error)
      end
    end
    unless subnets_to_delete.empty?
      process_cloud_subnets(subnets_to_delete, "destroy")
      # TODO: To replace with targeted refresh when avail. or either use tasks
      EmsRefresh.queue_refresh(ManageIQ::Providers::NetworkManager)
    end

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "cloud_subnet"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected Subnet was deleted") % {:model => ui_lookup(:table => "cloud_subnet")})
      end
    else
      drop_breadcrumb(:name => 'dummy', :url  => " ") # missing a bc to get correctly back so here's a dummy
      session[:flash_msgs] = @flash_array.dup if @flash_array
      redirect_to(previous_breadcrumb_url)
    end
  end

  def edit
    params[:id] = get_checked_subnet_id(params) unless params[:id].present?
    assert_privileges("cloud_subnet_edit")
    @subnet = find_record_with_rbac(CloudSubnet, params[:id])
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Edit Subnet \"%{name}\"") % {:model => ui_lookup(:table => 'cloud_subnet'), :name => @subnet.name},
      :url  => "/cloud_subnet/edit/#{@subnet.id}"
    )
  end

  def get_checked_subnet_id(params)
    if params[:id]
      checked_subnet_id = params[:id]
    else
      checked_subnets = find_checked_items
      checked_subnet_id = checked_subnets[0] if checked_subnets.length == 1
    end
    checked_subnet_id
  end

  def update
    assert_privileges("cloud_subnet_edit")
    @subnet = find_record_with_rbac(CloudSubnet, params[:id])
    case params[:button]
    when "cancel"
      cancel_action(_("Edit of Subnet \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'cloud_subnet'),
        :name  => @subnet.name
      })

    when "save"
      begin
        @subnet.update_subnet(form_params)
        add_flash(_("Updating Subnet \"%{name}\"") % {
          :model => ui_lookup(:table => 'cloud_subnet'),
          :name  => @subnet.name
        })
      rescue Excon::Error::Unauthorized => e
        add_flash(_("Unable to update Subnet \"%{name}\": The request you have made requires authentication.") % {
          :name    => @subnet.name,
          :details => e
        }, :error)
      rescue => e
        add_flash(_("Unable to update Subnet \"%{name}\": %{details}") % {
            :name    => @subnet.name,
            :details => e
        }, :error)
      end

      session[:edit] = nil
      session[:flash_msgs] = @flash_array.dup if @flash_array
      javascript_redirect previous_breadcrumb_url
    end
  end

  private

  def form_params
    params[:ip_version] ||= "4"
    params[:dhcp_enabled] ||= false
    options = {}
    options[:name] = params[:name] if params[:name]
    options[:ems_id] = params[:ems_id] if params[:ems_id]
    options[:cidr] = params[:cidr] if params[:cidr]
    options[:gateway] = params[:gateway] if params[:gateway]
    options[:ip_version] = params[:ip_version]
    options[:cloud_tenant] = find_record_with_rbac(CloudTenant, params[:cloud_tenant_id]) if params[:cloud_tenant_id]
    options[:network_id] = params[:network_id] if params[:network_id]
    # TODO: Adds following fields for create/update
    options[:dhcp_enabled] = params[:dhcp_enabled]
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
        begin
          subnet.delete_subnet
          deleted_subnets += 1
        rescue NotImplementedError
          add_flash(_("Cannot delete Network %{name}: Not supported.") % {:name => subnet.name}, :error)
        rescue MiqException::MiqCloudSubnetDeleteError => e
          add_flash(_("Cannot delete Network %{name}: %{error_message}") % {:name => subnet.name, :error_message => e.message}, :error)
        end
      end
      if  deleted_subnets > 0
        add_flash(n_("Delete initiated for %{number} Cloud Subnet.",
                     "Delete initiated for %{number} Cloud Subnets.",
                     deleted_subnets) % {:number =>  deleted_subnets})
      end
    end
  end
end
