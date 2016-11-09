class CloudNetworkController < ApplicationController
  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  include Mixins::GenericButtonMixin
  include Mixins::GenericListMixin
  include Mixins::GenericSessionMixin
  include Mixins::GenericShowMixin

  PROVIDERS_NETWORK_TYPES = {
    "Local" => "local",
    "Flat"  => "flat",
    "GRE"   => "gre",
    "VLAN"  => "vlan",
    "VXLAN" => "vxlan",
  }.freeze

  def self.display_methods
    %w(instances cloud_networks network_routers cloud_subnets)
  end

  def button
    @edit = session[:edit] # Restore @edit for adv search box
    params[:display] = @display if %w(vms instances images).include?(@display)
    params[:page] = @current_page unless @current_page.nil? # Save current page for list refresh

    @refresh_div = "main_div"
    return tag("CloudNetwork") if params[:pressed] == "cloud_network_tag"
    delete_networks if params[:pressed] == 'cloud_network_delete'

    if params[:pressed] == "cloud_network_edit"
      checked_network_id = get_checked_network_id(params)
      javascript_redirect :action => "edit", :id => checked_network_id
    elsif params[:pressed] == "cloud_network_new"
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
                        :id        => @network.id,
                        :display   => session[:cloud_network_display],
                        :flash_msg => message
  end

  def cloud_network_form_fields
    assert_privileges("cloud_network_edit")
    network = find_by_id_filtered(CloudNetwork, params[:id])
    render :json => {
      :name                  => network.name,
      :cloud_tenant_name     => network.cloud_tenant.name,
      :enabled               => network.enabled,
      :external_facing       => network.external_facing,
      :port_security_enabled => network.port_security_enabled,
      :provider_network_type => network.provider_network_type,
      :qos_policy_id         => network.qos_policy_id,
      :shared                => network.shared,
      :vlan_transparent      => network.vlan_transparent
    }
  end

  def create
    assert_privileges("cloud_network_new")
    case params[:button]
    when "cancel"
      javascript_redirect :action    => 'show_list',
                          :flash_msg => _("Add of new %{model} was cancelled by the user") % {
                            :model => ui_lookup(:table => 'cloud_network')
                          }

    when "add"
      @network = CloudNetwork.new
      options = form_params
      ems = ExtManagementSystem.find(options[:ems_id])
      valid_action, action_details = CloudNetwork.validate_create_network(ems)
      if valid_action
        begin
          CloudNetwork.create_network(ems, options)
          # TODO: To replace with targeted refresh when avail. or either use tasks
          EmsRefresh.queue_refresh(ManageIQ::Providers::NetworkManager)
          add_flash(_("Creating %{network} \"%{network_name}\"") % {
            :network      => ui_lookup(:table => 'cloud_network'),
            :network_name => options[:name]})
        rescue => ex
          add_flash(_("Unable to create %{network} \"%{network_name}\": %{details}") % {
            :network      => ui_lookup(:table => 'cloud_network'),
            :network_name => options[:name],
            :details      => ex}, :error)
        end
        @breadcrumbs.pop if @breadcrumbs
        session[:flash_msgs] = @flash_array.dup if @flash_array
        javascript_redirect :action => "show_list"
      else
        @in_a_form = true
        add_flash(_(action_details), :error) unless action_details.nil?
        drop_breadcrumb(
          :name => _("Add New %{model}") % {:model => ui_lookup(:table => 'cloud_network')},
          :url  => "/cloud_network/new"
        )
        javascript_flash
      end
    end
  end

  def delete_networks
    assert_privileges("cloud_network_delete")

    networks = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "cloud_network")
                 find_checked_items
               else
                 [params[:id]]
               end

    if networks.empty?
      add_flash(_("No %{models} were selected for deletion.") % {
        :models => ui_lookup(:tables => "cloud_network")
      }, :error)
    end

    networks_to_delete = []
    networks.each do |s|
      network = CloudNetwork.find_by_id(s)
      if network.nil?
        add_flash(_("%{model} no longer exists.") % {:model => ui_lookup(:table => "cloud_network")}, :error)
      else
        valid_delete, delete_details = network.validate_delete_network
        if valid_delete
          networks_to_delete.push(network)
        else
          add_flash(_("Couldn't initiate deletion of %{model} \"%{name}\": %{details}") % {
            :model   => ui_lookup(:table => 'cloud_network'),
            :name    => network.name,
            :details => delete_details}, :error)
        end
      end
    end
    unless networks_to_delete.empty?
      process_cloud_networks(networks_to_delete, "destroy")
      # TODO: Replace with targeted refresh when avail or either use tasks
      EmsRefresh.queue_refresh(ManageIQ::Providers::NetworkManager)
    end

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "cloud_network"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected %{model} was deleted") % {:model => ui_lookup(:table => "cloud_network")})
      end
    end
  end

  def edit
    assert_privileges("cloud_network_edit")
    @network = find_by_id_filtered(CloudNetwork, params[:id])
    @network_provider_network_type_choices = PROVIDERS_NETWORK_TYPES
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Edit %{model} \"%{name}\"") % {:model => ui_lookup(:table => 'cloud_network'), :name => @network.name},
      :url  => "/cloud_network/edit/#{@network.id}"
    )
  end

  def get_checked_network_id(params)
    if params[:id]
      checked_network_id = params[:id]
    else
      checked_networks = find_checked_items
      checked_network_id = checked_networks[0] if checked_networks.length == 1
    end
    checked_network_id
  end

  def new
    assert_privileges("cloud_network_new")
    @network = CloudNetwork.new
    @in_a_form = true
    @network_ems_provider_choices = {}
    ExtManagementSystem.where(:type => "ManageIQ::Providers::Openstack::NetworkManager").find_each do |ems|
      @network_ems_provider_choices[ems.name] = ems.id
    end
    @network_provider_network_type_choices = PROVIDERS_NETWORK_TYPES
    @cloud_tenant_choices = {}
    CloudTenant.all.each { |tenant| @cloud_tenant_choices[tenant.name] = tenant.id }

    drop_breadcrumb(
      :name => _("Add New %{model}") % {:model => ui_lookup(:table => 'cloud_network')},
      :url  => "/cloud_network/new"
    )
  end

  def update
    assert_privileges("cloud_network_edit")
    @network = find_by_id_filtered(CloudNetwork, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Edit of %{model} \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'cloud_network'),
        :name  => @network.name
      })

    when "save"
      options = edit_form_params
      begin
        @network.update_network(options)
        add_flash(_("Updating %{model} \"%{name}\"") % {
          :model => ui_lookup(:table => 'cloud_network'),
          :name  => @network.name
        })
      rescue => e
        add_flash(_("Unable to update %{model} \"%{name}\": %{details}") % {
          :model   => ui_lookup(:table => 'cloud_network'),
          :name    => @network.name,
          :details => e
        }, :error)
      end

      @breadcrumbs.pop if @breadcrumbs
      session[:edit] = nil
      session[:flash_msgs] = @flash_array.dup if @flash_array
      javascript_redirect :action => "show", :id => @network.id
    end
  end

  private

  def switch_to_bol(option)
    return true if option =~ /on|true/i
    return false
  end

  def edit_form_params
    options = {}
    # True by default
    params[:enabled] = false unless params[:enabled]
    params[:port_security_enabled] = false unless params[:port_security_enabled]
    params[:qos_policy_id] = nil if params[:qos_policy_id].empty?


    options[:name] = params[:name] if params[:name] unless @network.name == params[:name]
    options[:admin_state_up] = switch_to_bol(params[:enabled]) unless @network.enabled == switch_to_bol(params[:enabled])
    options[:shared] = switch_to_bol(params[:shared]) unless @network.shared == switch_to_bol(params[:shared])
    options[:external_facing] = switch_to_bol(params[:external_facing]) unless @network.external_facing == switch_to_bol(params[:external_facing])
    options[:port_security_enabled] = switch_to_bol(params[:port_security_enabled]) unless @network.port_security_enabled == switch_to_bol(params[:port_security_enabled])
    options[:qos_policy_id] = params[:qos_policy_id] unless @network.qos_policy_id == params[:qos_policy_id]
    options
  end

  def form_params
    options = {}
    # Admin_state_Up is true by default
    params[:enabled] = false unless params[:enabled]

    options[:name] = params[:name] if params[:name]
    options[:ems_id] = params[:ems_id] if params[:ems_id]
    options[:admin_state_up] = switch_to_bol(params[:enabled])
    options[:shared] = true if params[:shared]
    options[:external_facing] = true if params[:external_facing]
    options[:port_security_enabled] = params[:port_security_enabled] if params[:port_security_enabled]
    options[:qos_policy_id] = params[:qos_policy_id] if params[:qos_policy_id]
    options[:provider_network_type] = params[:provider_network_type] if params[:provider_network_type]
    options[:cloud_tenant_id] = params[:cloud_tenant_id] if params[:cloud_tenant_id]
    options
  end

  # dispatches operations to multiple networks
  def process_cloud_networks(networks, operation)
    return if networks.empty?

    if operation == "destroy"
      networks.each do |network|
        audit = {
          :event        => "cloud_network_record_delete_initiated",
          :message      => "[#{network.name}] Record delete initiated",
          :target_id    => network.id,
          :target_class => "CloudNetwork",
          :userid       => session[:userid]
        }
        AuditEvent.success(audit)
        network.delete_network
      end
      add_flash(n_("Delete initiated for %{number} Cloud Network.",
                   "Delete initiated for %{number} Cloud Networks.",
                   networks.length) % {:number => networks.length})
    end
  end

  menu_section :net
end
