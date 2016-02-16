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

    @orig_parameters = @stack.parameters.select { |x| x.name.include?('::count') || x.name.include?('Count') }

    return unless params[:scale]

    form_parameters = params.select { |k, _v| k.include?('::count') || k.include?('Count') }

    return unless validate_selected_hosts_not_exceed_available_hosts(form_parameters)

    changed_parameters = select_changed_parameters(form_parameters)
    return unless validate_a_change_was_made(changed_parameters)

    begin
      # Check if stack is ready to be updated
      update_ready = @stack.update_ready?
    rescue => ex
      log_and_flash_message(_("Unable to initiate scaling, obtaining of status failed: #{ex}"))
      return
    end

    unless update_ready
      add_flash(_("Provider is not ready to be scaled, another operation is in progress."), :error)
    end

    begin
      return_message = select_return_message(form_parameters)
      @stack.raw_update_stack(nil, changed_parameters)
      redirect_to :action => 'show', :id => params[:id], :flash_msg => return_message
    rescue => ex
      log_and_flash_message(_("Unable to initiate scaling: %s") % ex)
    end
  end

  private

  ############################

  def value_changed?(form_parameters, name, value)
    !form_parameters[name].nil? && form_parameters[name] != value
  end

  def changed_parameters(form_parameters)
    return enum_for(:changed_parameters, form_parameters) unless block_given?

    @orig_parameters.each do |orig|
      next unless value_changed?(form_parameters, orig.name, orig.value)
      yield orig.name, orig.value, form_parameters[orig.name]
    end
  end

  def select_changed_parameters(form_parameters)
    selected = {}
    changed_parameters(form_parameters).map do |name, _before, after|
      selected[name] = after
    end
    selected
  end

  def select_return_message(form_parameters)
    changes = changed_parameters(form_parameters).map do |name, before, after|
      _(" %{name} from %{value} to %{parameters} ") %
      {:name => name, :value => before, :parameters => after}
    end
    _("Scaling") << changes.join
  end

  def validate_a_change_was_made(changed_parameters)
    if changed_parameters.length == 0
      log_and_flash_message(_("A value must be changed or provider will not be scaled."))
      return false
    else
      return true
    end
  end

  def validate_selected_hosts_not_exceed_available_hosts(form_parameters)
    assigned_hosts = form_parameters.values.sum(&:to_i)
    infra = ManageIQ::Providers::Openstack::InfraManager.find(params[:id])
    if assigned_hosts > infra.hosts.count
      # Validate number of selected hosts is not more than available
      log_and_flash_message(_("Assigning %{hosts} but only have %{hosts_count} hosts available.") % {:hosts => assigned_hosts, :hosts_count => infra.hosts.count.to_s})
      return false
    else
      return true
    end
  end

  def log_and_flash_message(message)
    add_flash(message, :error)
    $log.error(message)
  end
end
