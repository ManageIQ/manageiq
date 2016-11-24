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
      checked_subnet_id = get_checked_item_id(params)
      javascript_redirect :action => "edit", :id => checked_subnet_id
    elsif params[:pressed] == "cloud_subnet_new"
      javascript_redirect :action => "new"
    elsif !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render_flash
    end
  end

  def cancel_action(message)
    session[:edit] = nil
    @breadcrumbs.pop if @breadcrumbs
    javascript_redirect :action    => @lastaction,
                        :id        => @subnet.id,
                        :display   => session[:cloud_subnet_display],
                        :flash_msg => message
  end

  def cloud_subnet_form_fields
    assert_privileges("cloud_subnet_edit")
    subnet = find_by_id_filtered(CloudSubnet, params[:id])
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
      :name => _("Add New Subnet"),
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
      valid_action, action_details = CloudSubnet.validate_create_subnet(ems)
      if valid_action
        begin
          CloudSubnet.create_subnet(ems, options)
          # TODO: To replace with targeted refresh when avail. or either use tasks
          EmsRefresh.queue_refresh(ManageIQ::Providers::NetworkManager)
          add_flash(_("Creating Cloud Subnet \"%{subnet_name}\"") % {:subnet_name => options[:name]})
        rescue => ex
          add_flash(_("Unable to create Cloud Subnet \"%{subnet_name}\": %{details}") % {
            :subnet_name => options[:name],
            :details     => ex}, :error)
        end
        @breadcrumbs.pop if @breadcrumbs
        session[:flash_msgs] = @flash_array.dup if @flash_array
        javascript_redirect :action => "show_list"
      else
        @in_a_form = true
        add_flash(_(action_details), :error) unless action_details.nil?
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

    subnets = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "cloud_subnet")
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
      else
        valid_delete, delete_details = subnet.validate_delete_subnet
        if valid_delete
          subnets_to_delete.push(subnet)
        else
          add_flash(_("Couldn't initiate deletion of Subnet \"%{name}\": %{details}") % {
            :name    => subnet.name,
            :details => delete_details}, :error)
        end
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
        add_flash(_("The selected Cloud Subnet was deleted"))
      end
    end
  end

  def edit
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

    case params[:button]
    when "cancel"
      cancel_action(_("Edit of Subnet \"%{name}\" was cancelled by the user") % {:name  => @subnet.name})

    when "save"
      begin
        @subnet.update_subnet(form_params)
        add_flash(_("Updating Subnet \"%{name}\"") % {
          :name  => @subnet.name
        })
      rescue => e
        add_flash(_("Unable to update Subnet \"%{name}\": %{details}") % {
          :name    => @subnet.name,
          :details => e
        }, :error)
      end

      @breadcrumbs.pop if @breadcrumbs
      session[:edit] = nil
      session[:flash_msgs] = @flash_array.dup if @flash_array
      javascript_redirect :action => "show", :id => @subnet.id
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
    options[:cloud_tenant_id] = params[:cloud_tenant_id] if params[:cloud_tenant_id]
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
      subnets.each do |subnet|
        audit = {
          :event        => "cloud_subnet_record_delete_initiated",
          :message      => "[#{subnet.name}] Record delete initiated",
          :target_id    => subnet.id,
          :target_class => "CloudSubnet",
          :userid       => session[:userid]
        }
        AuditEvent.success(audit)
        subnet.delete_subnet
      end
      add_flash(n_("Delete initiated for %{number} Cloud Subnet.",
                   "Delete initiated for %{number} Cloud Subnets.",
                   subnets.length) % {:number => subnets.length})
    end
  end

  menu_section :net
end
