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

      begin
        # Check if stack is ready to be updated
        update_ready = @stack.update_ready?
      rescue => ex
        log_and_flash_message(_("Unable to initiate scaling, obtaining of status failed: #{ex}"))
        return
      end

      if !update_ready
        add_flash(_("Provider is not ready to be scaled, another operation is in progress."), :error)
      elsif scale_parameters_formatted.length > 0
        # A value was changed
        begin
          @stack.raw_update_stack(nil, scale_parameters_formatted)
          redirect_to :action => 'show', :id => params[:id], :flash_msg => return_message
        rescue => ex
          log_and_flash_message(_("Unable to initiate scaling: %s") % ex)
        end
      else
        # No values were changed
        add_flash(_("A value must be changed or provider will not be scaled."), :error)
      end
    end
  end

  private

  ############################
  def log_and_flash_message(message)
    add_flash(message, :error)
    $log.error(message)
  end
end
