class EmsInfraController < ApplicationController
  include EmsCommon        # common methods for EmsInfra/Cloud controllers

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::InfraManager
  end

  def self.table_name
    @table_name ||= "ems_infra"
  end

  def index
    redirect_to :action => 'show_list'
  end

  def scaling
    assert_privileges("ems_infra_scale")

    # Hiding the toolbars
    @in_a_form = true

    redirect_to :action => 'show', :id => params[:id] if params[:cancel]

    drop_breadcrumb(:name => _("Scale Infrastructure Provider"), :url => "/ems_infra/scaling")
    @infra = ManageIQ::Providers::Openstack::InfraManager.find(params[:id])
    # TODO: Currently assumes there is a single stack per infrastructure provider. This should
    # be improved to support multiple stacks.
    @stack = @infra.direct_orchestration_stacks.first
    if @stack.nil?
      log_and_flash_message(_("Orchestration stack could not be found."))
      return
    end

    @count_parameters = @stack.parameters.select { |x| x.name.include?('::count') || x.name.include?('Count') }

    return unless params[:scale]

    scale_parameters = params.select { |k, _v| k.include?('::count') || k.include?('Count') }.to_unsafe_h
    assigned_hosts = scale_parameters.values.sum(&:to_i)
    infra = ManageIQ::Providers::Openstack::InfraManager.find(params[:id])
    if assigned_hosts > infra.hosts.count
      # Validate number of selected hosts is not more than available
      log_and_flash_message(_("Assigning %{hosts} but only have %{hosts_count} hosts available.") % {:hosts => assigned_hosts, :hosts_count => infra.hosts.count.to_s})
    else
      scale_parameters_formatted = {}
      return_message = _("Scaling")
      @count_parameters.each do |p|
        if !scale_parameters[p.name].nil? && scale_parameters[p.name] != p.value
          return_message += _(" %{name} from %{value} to %{parameters} ") % {:name => p.name, :value => p.value, :parameters => scale_parameters[p.name]}
          scale_parameters_formatted[p.name] = scale_parameters[p.name]
        end
      end

      update_stack(@stack, scale_parameters_formatted, params[:id], return_message)
    end
  end

  def scaledown
    assert_privileges("ems_infra_scale")
    redirect_to :action => 'show', :id => params[:id] if params[:cancel]

    # Hiding the toolbars
    @in_a_form = true

    drop_breadcrumb(:name => _("Scale Infrastructure Provider Down"), :url => "/ems_infra/scaling")
    @infra = ManageIQ::Providers::Openstack::InfraManager.find(params[:id])
    # TODO: Currently assumes there is a single stack per infrastructure provider. This should
    # be improved to support multiple stacks.
    @stack = @infra.direct_orchestration_stacks.first
    if @stack.nil?
      log_and_flash_message(_("Orchestration stack could not be found."))
      return
    end

    @compute_hosts = @infra.hosts.select { |host| host.name.include?('Compute') }

    return unless params[:scaledown]

    host_ids = params[:host_ids]
    if host_ids.nil?
      log_and_flash_message(_("No compute hosts were selected for scale down."))
    else
      hosts = host_ids.map { |host_id| find_by_id_filtered(Host, host_id) }

      # verify selected nodes can be removed
      has_invalid_nodes, error_return_message = verify_hosts_for_scaledown(hosts)
      if has_invalid_nodes
        log_and_flash_message(error_return_message)
        return
      end

      # figure out scaledown parameters and update stack
      stack_parameters = get_scaledown_parameters(hosts, @infra, @compute_hosts)
      return_message = _(" Scaling down to %{a} compute nodes") % {:a => stack_parameters['ComputeCount']}
      update_stack(@stack, stack_parameters, params[:id], return_message)
    end
  end

  def ems_infra_form_fields
    assert_privileges("#{permission_prefix}_edit")
    @ems = model.new if params[:id] == 'new'
    @ems = find_by_id_filtered(model, params[:id]) if params[:id] != 'new'

    if @ems.zone.nil? || @ems.my_zone == ""
      zone = "default"
    else
      zone = @ems.my_zone
    end

    amqp_userid = @ems.has_authentication_type?(:amqp) ? @ems.authentication_userid(:amqp).to_s : ""

    if @ems.kind_of?(ManageIQ::Providers::Openstack::InfraManager)
      security_protocol = @ems.security_protocol ? @ems.security_protocol : 'ssl'
    else
      if @ems.id
        security_protocol = @ems.security_protocol ? @ems.security_protocol : 'ssl'
      else
        security_protocol = 'kerberos'
      end
    end

    @ems_types = Array(model.supported_types_and_descriptions_hash.invert).sort_by(&:first)

    render :json => {:name                            => @ems.name,
                     :provider_region                 => @ems.provider_region,
                     :emstype                         => @ems.emstype,
                     :zone                            => zone,
                     :provider_id                     => @ems.provider_id ? @ems.provider_id : "",
                     :hostname                        => @ems.hostname,
                     :api_port                        => @ems.port,
                     :api_version                     => @ems.api_version,
                     :security_protocol               => security_protocol,
                     :provider_region                 => @ems.provider_region,
                     :default_userid                  => @ems.authentication_userid ? @ems.authentication_userid : "",
                     :amqp_userid                     => amqp_userid,
                     :azure_tenant_id                 => azure_tenant_id ? azure_tenant_id : "",
                     :client_id                       => client_id ? client_id : "",
                     :client_key                      => client_key ? client_key : "",
                     :emstype_vm                      => @ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
    }
  end

  private

  ############################
  def show_link(ems, options = {})
    ems_infra_path(ems.id, options)
  end

  def log_and_flash_message(message)
    add_flash(message, :error)
    $log.error(message)
  end

  def update_stack(stack, stack_parameters, provider_id, return_message)
    begin
      # Check if stack is ready to be updated
      update_ready = stack.update_ready?
    rescue => ex
      log_and_flash_message(_("Unable to update stack, obtaining of status failed: %{message}") %
                            {:message => ex})
      return
    end

    if !update_ready
      add_flash(_("Provider stack is not ready to be updated, another operation is in progress."), :error)
    elsif !stack_parameters.empty?
      # A value was changed
      begin
        stack.raw_update_stack(nil, stack_parameters)
        redirect_to :action => 'show', :id => provider_id, :flash_msg => return_message
      rescue => ex
        log_and_flash_message(_("Unable to initiate scaling: %{message}") % {:message => ex})
      end
    else
      # No values were changed
      add_flash(_("A value must be changed or provider stack will not be updated."), :error)
    end
  end

  def verify_hosts_for_scaledown(hosts)
    has_invalid_nodes = false
    error_return_message = _("Not all hosts can be removed from the deployment.")

    hosts.each do |host|
      unless host.maintenance
        has_invalid_nodes = true
        error_return_message += _(" %{host_uid_ems} needs to be in maintenance mode before it can be removed ") %
                                {:host_uid_ems => host.uid_ems}
      end
      if host.number_of(:vms) > 0
        has_invalid_nodes = true
        error_return_message += _(" %{host_uid_ems} needs to be evacuated before it can be removed ") %
                                {:host_uid_ems => host.uid_ems}
      end
      unless host.name.include?('Compute')
        has_invalid_nodes = true
        error_return_message += _(" %{host_uid_ems} is not a compute node ") % {:host_uid_ems => host.uid_ems}
      end
    end

    return has_invalid_nodes, error_return_message
  end

  def get_scaledown_parameters(hosts, provider, compute_hosts)
    resources_by_physical_resource_id = {}
    provider.orchestration_stacks.each do |s|
      s.resources.each do |r|
        resources_by_physical_resource_id[r.physical_resource] = r
      end
    end

    host_physical_resource_ids = hosts.map(&:ems_ref_obj)
    parent_resource_names = []
    host_physical_resource_ids.each do |pr_id|
      host_resource = resources_by_physical_resource_id[pr_id]
      host_stack = find_by_id_filtered(OrchestrationStack, host_resource.stack_id)
      parent_host_resource = resources_by_physical_resource_id[host_stack.ems_ref]
      parent_resource_names << parent_host_resource.logical_resource
    end

    stack_parameters = {}
    stack_parameters['ComputeCount'] = compute_hosts.length - hosts.length
    stack_parameters['ComputeRemovalPolicies'] = [{:resource_list => parent_resource_names}]
    return stack_parameters
  end
end
