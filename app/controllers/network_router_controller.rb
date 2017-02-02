class NetworkRouterController < ApplicationController
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
    return tag("NetworkRouter") if params[:pressed] == "network_router_tag"
    delete_network_routers if params[:pressed] == 'network_router_delete'

    if params[:pressed] == "network_router_edit"
      checked_router_id = get_checked_router_id(params)
      javascript_redirect :action => "edit", :id => checked_router_id
    elsif params[:pressed] == "network_router_new"
      javascript_redirect :action => "new"
    elsif params[:pressed] == "network_router_add_interface"
      checked_router_id = get_checked_router_id(params)
      javascript_redirect :action => "add_interface_select", :id => checked_router_id
    elsif params[:pressed] == "network_router_remove_interface"
      checked_router_id = get_checked_router_id(params)
      javascript_redirect :action => "remove_interface_select", :id => checked_router_id
    elsif !flash_errors? && @refresh_div == "main_div" && @lastaction == "show_list"
      replace_gtl_main_div
    else
      render_flash
    end
  end

  def network_router_form_fields
    assert_privileges("network_router_edit")
    router = find_by_id_filtered(NetworkRouter, params[:id])
    render :json => {
      :name => router.name
    }
  end

  def network_router_networks_by_ems
    assert_privileges("network_router_new")
    networks = []
    available_networks = CloudNetwork.where(:ems_id => params[:id]).find_each
    available_networks.each do |network|
      networks << { 'name' => network.name, 'id' => network.id }
    end
    render :json => {
      :available_networks => networks
    }
  end

  def new
    @router = NetworkRouter.new
    assert_privileges("network_router_new")
    @in_a_form = true
    @network_provider_choices = {}
    ExtManagementSystem.where(:type => "ManageIQ::Providers::Openstack::NetworkManager").find_each do |ems|
      @network_provider_choices[ems.name] = ems.id
    end
    @cloud_tenant_choices = {}
    CloudTenant.all.each { |tenant| @cloud_tenant_choices[tenant.name] = tenant.id }
    drop_breadcrumb(
      :name => _("Add New Router") % {:model => ui_lookup(:table => 'network_router')},
      :url  => "/network_router/new"
    )
  end

  def create
    assert_privileges("network_router_new")
    case params[:button]
    when "cancel"
      javascript_redirect :action    => 'show_list',
                          :flash_msg => _("Add of new Router was cancelled by the user") % {
                            :model => ui_lookup(:table => 'network_router')}

    when "add"
      @router = NetworkRouter.new
      options = form_params(params)
      ems = ExtManagementSystem.find(options[:ems_id])
      options.delete(:ems_id)
      task_id = ems.create_network_router_queue(session[:userid], options)

      add_flash(_("Network Router creation failed: Task start failed: ID [%{id}]") %
                {:id => task_id.inspect}, :error) unless task_id.kind_of?(Fixnum)

      if @flash_array
        javascript_flash(:spinner_off => true)
      else
        initiate_wait_for_task(:task_id => task_id, :action => "create_finished")
      end
    end
  end

  def create_finished
    task_id = session[:async][:params][:task_id]
    router_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("%{model} \"%{name}\" created") % { :model => ui_lookup(:table => 'network_router'),
                                                      :name  => router_name })
    else
      add_flash(
        _("Unable to create %{model} \"%{name}\": %{details}") % { :model   => ui_lookup(:table => 'network_router'),
                                                                   :name    => router_name,
                                                                   :details => task.message }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show_list"
  end

  def delete_network_routers
    assert_privileges("network_router_delete")

    routers = if @lastaction == "show_list" ||
                 (@lastaction == "show" && @layout != "network_router") ||
                 @lastaction.nil?
                find_checked_items
              else
                [params[:id]]
              end

    if routers.empty?
      add_flash(_("No router were selected for deletion.") % {
        :models => ui_lookup(:tables => "network_router")
      }, :error)
    end

    routers_to_delete = []
    routers.each do |s|
      router = NetworkRouter.find_by_id(s)
      if router.nil?
        add_flash(_("Router no longer exists.") % {:model => ui_lookup(:table => "network_router")}, :error)
      else
        routers_to_delete.push(router)
      end
    end
    process_network_routers(routers_to_delete, "destroy") unless routers_to_delete.empty?

    # refresh the list if applicable
    if @lastaction == "show_list" && @breadcrumbs.last[:url].include?(@lastaction)
      show_list
      @refresh_partial = "layouts/gtl"
    elsif @lastaction == "show" && @layout == "network_router"
      @single_delete = true unless flash_errors?
      if @flash_array.nil?
        add_flash(_("The selected Router was deleted") % {:model => ui_lookup(:table => "network_router")})
      end
    else
      drop_breadcrumb(:name => 'dummy', :url => " ") # missing a bc to get correctly back so here's a dummy
      session[:flash_msgs] = @flash_array.dup if @flash_array
      redirect_to(previous_breadcrumb_url)
    end
  end

  def edit
    params[:id] = get_checked_router_id(params) unless params[:id].present?
    assert_privileges("network_router_edit")
    @router = find_by_id_filtered(NetworkRouter, params[:id])
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Edit Router \"%{name}\"") % {:model => ui_lookup(:table => 'network_router'), :name => @router.name},
      :url  => "/network_router/edit/#{@router.id}"
    )
  end

  def get_checked_router_id(params)
    if params[:id]
      checked_router_id = params[:id]
    else
      checked_routers = find_checked_items
      checked_router_id = checked_routers[0] if checked_routers.length == 1
    end
    checked_router_id
  end

  def update
    assert_privileges("network_router_edit")
    @router = find_by_id_filtered(NetworkRouter, params[:id])
    options = form_params(params)
    case params[:button]
    when "cancel"
      cancel_action(_("Edit of Router \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'network_router'),
        :name  => @router.name
      })

    when "save"
      task_id = @router.update_network_router_queue(session[:userid], options)

      add_flash(_("Router update failed: Task start failed: ID [%{id}]") %
                {:id => task_id.inspect}, :error) unless task_id.kind_of?(Fixnum)

      if @flash_array
        javascript_flash(:spinner_off => true)
      else
        initiate_wait_for_task(:task_id => task_id, :action => "update_finished")
      end
    end
  end

  def update_finished
    task_id = session[:async][:params][:task_id]
    router_id = session[:async][:params][:id]
    router_name = session[:async][:params][:name]
    task = MiqTask.find(task_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("%{model} \"%{name}\" updated") % { :model => ui_lookup(:table => 'network_router'),
                                                      :name  => router_name })
    else
      add_flash(
        _("Unable to update %{model} \"%{name}\": %{details}") % { :model   => ui_lookup(:table => 'network_router'),
                                                                   :name    => router_name,
                                                                   :details => task.message }, :error)
    end

    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array
    javascript_redirect previous_breadcrumb_url
  end

  def add_interface_select
    assert_privileges("network_router_add_interface")
    @router = find_by_id_filtered(NetworkRouter, params[:id])
    @in_a_form = true
    @subnet_choices = {}

    (@router.ext_management_system.cloud_subnets - @router.cloud_subnets).each do |subnet|
      @subnet_choices[subnet.name] = subnet.id
    end
    if @subnet_choices.empty?
      add_flash(_("No subnets available to add interfaces to Router \"%{name}\"") % {
        :name => @router.name
      }, :error)
      session[:flash_msgs] = @flash_array
      @in_a_form = false
      if @lastaction == "show_list"
        redirect_to(:action => "show_list")
      else
        redirect_to(:action => "show", :id => params[:id])
      end
    else
      drop_breadcrumb(
        :name => _("Add Interface to Router \"%{name}\"") % {:name => @router.name},
        :url  => "/network_router/add_interface/#{@router.id}"
      )
    end
  end

  def add_interface
    assert_privileges("network_router_add_interface")
    @router = find_by_id_filtered(NetworkRouter, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Add Interface on Subnet to Router \"%{name}\" was cancelled by the user") % {
        :name => @router.name
      })

    when "add"
      options = form_params(params)
      cloud_subnet = find_by_id_filtered(CloudSubnet, options[:cloud_subnet_id])

      if @router.supports?(:add_interface)
        task_id = @router.add_interface_queue(session[:userid], cloud_subnet)

        unless task_id.kind_of?(Fixnum)
          add_flash(_("Add Interface on Subnet to Router \"%{name}\" failed: Task start failed: ID [%{id}]") % {
            :name => @router.name,
            :id   => task_id.inspect
          }, :error)
        end

        if @flash_array
          javascript_flash(:spinner_off => true)
        else
          initiate_wait_for_task(:task_id => task_id, :action => "add_interface_finished")
        end
      else
        @in_a_form = true
        add_flash(_("Add Interface not supported by Router \"%{name}\"") % {
          :name => @router.name
        }, :error)
        @breadcrumbs.pop if @breadcrumbs
        javascript_flash
      end
    end
  end

  def add_interface_finished
    task_id = session[:async][:params][:task_id]
    router_id = session[:async][:params][:id]
    router_name = session[:async][:params][:name]
    cloud_subnet_id = session[:async][:params][:cloud_subnet_id]

    task = MiqTask.find(task_id)
    cloud_subnet = CloudSubnet.find(cloud_subnet_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Subnet \"%{subnetname}\" added to Router \"%{name}\"") % {
        :subnetname => cloud_subnet.name,
        :name       => router_name
      })
    else
      add_flash(_("Unable to add Subnet \"%{name}\": %{details}") % {
        :name    => router_name,
        :details => task.message
      }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show", :id => router_id
  end

  def remove_interface_select
    assert_privileges("network_router_remove_interface")
    @router = find_by_id_filtered(NetworkRouter, params[:id])
    @in_a_form = true
    @subnet_choices = {}

    @router.cloud_subnets.each do |subnet|
      @subnet_choices[subnet.name] = subnet.id
    end
    if @subnet_choices.empty?
      add_flash(_("No subnets to remove interfaces to Router \"%{name}\"") % {
        :name => @router.name
      }, :error)
      session[:flash_msgs] = @flash_array
      @in_a_form = false
      if @lastaction == "show_list"
        redirect_to(:action => "show_list")
      else
        redirect_to(:action => "show", :id => params[:id])
      end
    else
      drop_breadcrumb(
        :name => _("Remove Interface from Router \"%{name}\"") % {:name => @router.name},
        :url  => "/network_router/remove_interface/#{@router.id}"
      )
    end
  end

  def remove_interface
    assert_privileges("network_router_remove_interface")
    @router = find_by_id_filtered(NetworkRouter, params[:id])

    case params[:button]
    when "cancel"
      cancel_action(_("Remove Interface on Subnet from Router \"%{name}\" was cancelled by the user") % {
        :name => @router.name
      })

    when "remove"
      options = form_params(params)
      cloud_subnet = find_by_id_filtered(CloudSubnet, options[:cloud_subnet_id])

      if @router.supports?(:remove_interface)
        task_id = @router.remove_interface_queue(session[:userid], cloud_subnet)

        unless task_id.kind_of?(Fixnum)
          add_flash(_("Remove Interface on Subnet from Router \"%{name}\" failed: Task start failed: ID [%{id}]") % {
            :name => @router.name,
            :id   => task_id.inspect
          }, :error)
        end

        if @flash_array
          javascript_flash(:spinner_off => true)
        else
          initiate_wait_for_task(:task_id => task_id, :action => "remove_interface_finished")
        end
      else
        @in_a_form = true
        add_flash(_("Remove Interface not supported by Router \"%{name}\"") % {
          :name => @router.name
        }, :error)
        @breadcrumbs.pop if @breadcrumbs
        javascript_flash
      end
    end
  end

  def remove_interface_finished
    task_id = session[:async][:params][:task_id]
    router_id = session[:async][:params][:id]
    router_name = session[:async][:params][:name]
    cloud_subnet_id = session[:async][:params][:cloud_subnet_id]

    task = MiqTask.find(task_id)
    cloud_subnet = CloudSubnet.find(cloud_subnet_id)
    if MiqTask.status_ok?(task.status)
      add_flash(_("Subnet \"%{subnetname}\" removed from Router \"%{name}\"") % {
        :subnetname => cloud_subnet.name,
        :name       => router_name
      })
    else
      add_flash(_("Unable to remove Subnet \"%{name}\": %{details}") % {
        :name    => router_name,
        :details => task.message
      }, :error)
    end

    @breadcrumbs.pop if @breadcrumbs
    session[:edit] = nil
    session[:flash_msgs] = @flash_array.dup if @flash_array

    javascript_redirect :action => "show", :id => router_id
  end

  private

  def form_params(in_params)
    options = {}
    [:name, :ems_id, :admin_state_up, :cloud_group_id,
     :cloud_subnet_id, :cloud_network_id].each do |param|
      options[param] = in_params[param] if in_params[param]
    end
    options[:cloud_network_id].gsub!(/number:/, '') if options[:cloud_network_id]
    if in_params[:cloud_tenant_id]
      options[:cloud_tenant] = find_by_id_filtered(CloudTenant, in_params[:cloud_tenant_id])
    end
    options
  end

  # dispatches operations to multiple routers
  def process_network_routers(routers, operation)
    return if routers.empty?

    if operation == "destroy"
      routers.each do |router|
        audit = {
          :event        => "network_router_record_delete_initiated",
          :message      => "[#{router.name}] Record delete initiated",
          :target_id    => router.id,
          :target_class => "NetworkRouter",
          :userid       => session[:userid]
        }
        AuditEvent.success(audit)
        router.delete_network_router_queue(session[:userid])
      end
      add_flash(n_("Delete initiated for %{number} Network Router.",
                   "Delete initiated for %{number} Network Routers.",
                   routers.length) % {:number => routers.length})
    end
  end
end
