class NetworkRouterController < ApplicationController
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
    return tag("NetworkRouter") if params[:pressed] == "network_router_tag"
    delete_network_routers if params[:pressed] == 'network_router_delete'

    if params[:pressed] == "network_router_edit"
      javascript_redirect :action => "edit", :id => checked_item_id
    elsif params[:pressed] == "network_router_new"
      javascript_redirect :action => "new"
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
      options = form_params
      ems = ExtManagementSystem.find(options[:ems_id])
      options.delete(:ems_id)
      task_id = ems.create_network_router_queue(session[:userid], options)

      add_flash(_("Network Router creation failed: Task start failed: ID [%{id}]") %
                {:id => task_id.to_s}, :error) unless task_id.kind_of?(Fixnum)

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
    params[:id] = checked_item_id unless params[:id].present?
    assert_privileges("network_router_edit")
    @router = find_by_id_filtered(NetworkRouter, params[:id])
    @in_a_form = true
    drop_breadcrumb(
      :name => _("Edit Router \"%{name}\"") % {:model => ui_lookup(:table => 'network_router'), :name => @router.name},
      :url  => "/network_router/edit/#{@router.id}"
    )
  end

  def update
    assert_privileges("network_router_edit")
    @router = find_by_id_filtered(NetworkRouter, params[:id])
    options = form_params
    case params[:button]
    when "cancel"
      cancel_action(_("Edit of Router \"%{name}\" was cancelled by the user") % {
        :model => ui_lookup(:table => 'network_router'),
        :name  => @router.name
      })

    when "save"
      task_id = @router.update_network_router_queue(session[:userid], options)

      add_flash(_("Router update failed: Task start failed: ID [%{id}]") %
                {:id => task_id.to_s}, :error) unless task_id.kind_of?(Fixnum)

      if @flash_array
        javascript_flash(:spinner_off => true)
      else
        initiate_wait_for_task(:task_id => task_id, :action => "update_finished")
      end
    end
  end

  def update_finished
    task_id = session[:async][:params][:task_id]
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

  private

  def form_params
    options = {}
    options[:name] = params[:name] if params[:name]
    options[:ems_id] = params[:ems_id] if params[:ems_id]
    options[:admin_state_up] = params[:admin_state_up] if params[:admin_state_up]

    # Relationships
    options[:cloud_tenant] = find_by_id_filtered(CloudTenant, params[:cloud_tenant_id]) if params[:cloud_tenant_id]
    options[:cloud_network_id] = params[:cloud_network_id].gsub(/number:/, '') if params[:cloud_network_id]
    options[:cloud_group_id] = params[:cloud_group_id] if params[:cloud_group_id]
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

  menu_section :net
end
