class CloudNetworkController < ApplicationController
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

    case params[:pressed]
    when "cloud_network_tag"
      return tag("CloudNetwork")
    when 'cloud_network_delete'
      delete_networks
    when "cloud_network_edit"
      javascript_redirect :action => "edit", :id => checked_item_id
    when "cloud_network_new"
      javascript_redirect :action => "new"
    else
      if !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
        replace_gtl_main_div
      else
        render_flash
      end
    end
  end

  def cloud_network_form_fields
    assert_privileges("cloud_network_edit")
    network = find_by_id_filtered(CloudNetwork, params[:id])
    render :json => {
      :name                  => network.name,
      :cloud_tenant_name     => network.cloud_tenant.try(:name),
      :enabled               => network.enabled,
      :external_facing       => network.external_facing,
      # TODO: uncomment once form contains this field
      #:port_security_enabled => network.port_security_enabled,
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
                          :flash_msg => _("Add of new Cloud Network was cancelled by the user")

    when "add"
      @network = CloudNetwork.new
      options = form_params
      ems = ExtManagementSystem.find(options[:ems_id])
      if CloudNetwork.class_by_ems(ems).supports_create?
        options.delete(:ems_id)
        task_id = ems.create_cloud_network_queue(session[:userid], options)
        add_flash(_("Cloud Network creation failed: Task start failed: ID [%{id}]") %
        {:id => task_id.to_s}, :error) unless task_id.kind_of?(Integer)
        if @flash_array
          javascript_flash(:spinner_off => true)
        else
          initiate_wait_for_task(:task_id => task_id, :action => "create_finished")
        end
      else
        @in_a_form = true
        add_flash(_(CloudNetwork.unsupported_reason(:create)), :error)
        drop_breadcrumb(:name => _("Add New Cloud Network "), :url  => "/cloud_network/new")
        javascript_flash
      end
    end
  end

  def create_finished
    task_id = session[:async][:params][:task_id]
    network_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Cloud Network \"%{name}\" created") % {:name  => network_name })
    else
      add_flash(
        _("Unable to create Cloud Network \"%{name}\": %{details}") % { :name    => network_name,
                                                                        :details => task.message }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array
    javascript_redirect :action => "show_list"
  end

  def delete_networks
    assert_privileges("cloud_network_delete")

    networks = if @lastaction == "show_list" || (@lastaction == "show" && @layout != "cloud_network") || @lastaction.nil?
                 find_checked_items
               else
                 [params[:id]]
               end
    if networks.empty?
      add_flash(_("No Cloud Network were selected for deletion."), :error)
    else
      networks_to_delete = []
      networks.each do |s|
        network = CloudNetwork.find_by_id(s)
        if network.nil?
          add_flash(_("Cloud Network no longer exists."), :error)
        elsif network.supports_delete?
          networks_to_delete.push(network)
        else
          add_flash(_("Couldn't initiate deletion of Network \"%{name}\": %{details}") % {
            :name    => network.name,
            :details => network.unsupported_reason(:delete)
          }, :error)
        end
      end
      unless networks_to_delete.empty?
        process_cloud_networks(networks_to_delete, "destroy")
      end
    end

    # refresh the list if applicable
    if @lastaction == "show_list"
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "cloud_network"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected Cloud Network was deleted"))
      end
    end
  end

  def edit
    params[:id] = checked_item_id unless params[:id].present?
    assert_privileges("cloud_network_edit")
    @network = find_by_id_filtered(CloudNetwork, params[:id])
    @network_provider_network_type_choices = PROVIDERS_NETWORK_TYPES
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Edit Cloud Network \"%{name}\"") % {:name => @network.name},
      :url  => "/cloud_network/edit/#{@network.id}"
    )
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

    drop_breadcrumb(:name => _("Add New Cloud Network"), :url => "/cloud_network/new")
  end

  def update
    assert_privileges("cloud_network_edit")
    @network = find_by_id_filtered(CloudNetwork, params[:id])
    options = edit_form_params
    case params[:button]
    when "cancel"
      cancel_action(_("Edit of Cloud Network \"%{name}\" was cancelled by the user") % { :name  => @network.name })

    when "save"
      if @network.supports_update?
        task_id = @network.update_cloud_network_queue(session[:userid], options)
        add_flash(_("Cloud Network update failed: Task start failed: ID [%{id}]") %
        {:id => task_id.to_s}, :error) unless task_id.kind_of?(Integer)
        if @flash_array
          javascript_flash(:spinner_off => true)
        else
          initiate_wait_for_task(:task_id => task_id, :action => "update_finished")
        end
      else
        add_flash(_("Couldn't initiate update of Network \"%{name}\": %{details}") % {
          :name    => @network.name,
          :details => @network.unsupported_reason(:delete)
        }, :error)
      end
    end
  end

  def update_finished
    task_id = session[:async][:params][:task_id]
    cloud_network_id = session[:async][:params][:id]
    cloud_network_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Cloud Network \"%{name}\" updated") % { :name  => cloud_network_name })
    else
      add_flash(
        _("Unable to update Cloud Network \"%{name}\": %{details}") % { :name    => cloud_network_name,
                                                                        :details => task.message }, :error)
    end

    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array
    javascript_redirect previous_breadcrumb_url
  end

  private

  def switch_to_bol(option)
    return true if option && option =~ /on|true/i
    return false
  end

  def edit_form_params
    options = {}
    # True by default
    params[:enabled] = false unless params[:enabled]
    # TODO: uncomment once form contains this field
    # params[:port_security_enabled] = false unless params[:port_security_enabled]
    params[:qos_policy_id] = nil if params[:qos_policy_id] && params[:qos_policy_id].empty?

    options[:name] = params[:name] if params[:name] unless @network.name == params[:name]
    options[:admin_state_up] = switch_to_bol(params[:enabled]) unless @network.enabled == switch_to_bol(params[:enabled])
    options[:shared] = switch_to_bol(params[:shared]) unless @network.shared == switch_to_bol(params[:shared])
    unless @network.external_facing == switch_to_bol(params[:external_facing])
      options[:external_facing] = switch_to_bol(params[:external_facing])
    end
    # TODO: uncomment once form contains this field
    # options[:port_security_enabled] = switch_to_bol(params[:port_security_enabled]) unless @network.port_security_enabled == switch_to_bol(params[:port_security_enabled])
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
    options[:shared] = switch_to_bol(params[:shared])
    options[:external_facing] = switch_to_bol(params[:external_facing])
    # TODO: uncomment once form contains this field
    # options[:port_security_enabled] = params[:port_security_enabled] if params[:port_security_enabled]
    options[:qos_policy_id] = params[:qos_policy_id] if params[:qos_policy_id]
    options[:provider_network_type] = params[:provider_network_type] if params[:provider_network_type]
    options[:cloud_tenant] = find_by_id_filtered(CloudTenant, params[:cloud_tenant_id]) if params[:cloud_tenant_id]
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
        network.delete_cloud_network_queue(session[:userid])
      end
      add_flash(n_("Delete initiated for %{number} Cloud Network.",
                   "Delete initiated for %{number} Cloud Networks.",
                   networks.length) % {:number => networks.length})
    end
  end

  menu_section :net
end
