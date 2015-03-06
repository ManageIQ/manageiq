class EmsInfraController < ApplicationController
  include EmsCommon        # common methods for EmsInfra/Cloud controllers

  before_filter :check_privileges
  before_filter :get_session_data
  after_filter :cleanup_action
  after_filter :set_session_data

  def self.model
    EmsInfra
  end

  def self.table_name
    @table_name ||= "ems_infra"
  end

  def index
    redirect_to :action => 'show_list'
  end

  def scaling
    assert_privileges("ems_infra_scale")

    redirect_to :action => 'show', :id => params[:id] if params[:cancel]

    drop_breadcrumb(:name => _("Scale Infrastructure Provider"), :url => "/ems_infra/scaling")
    @infra = EmsOpenstackInfra.find(params[:id])
    # TODO: Currently assumes there is a single stack per infrastructure provider. This should
    # be improved to support multiple stacks.
    @stack = @infra.orchestration_stacks.first
    @count_parameters = @stack.parameters.select { |x| x.name.include?('::count') }

    return unless params[:scale]

    scale_parameters = params.select { |k, _v| k.include?('::count') }
    assigned_hosts = scale_parameters.values.sum(&:to_i)
    infra = EmsOpenstackInfra.find(params[:id])
    if assigned_hosts > infra.hosts.count
      # Validate number of selected hosts is not more than available
      message = _("Assigning #{assigned_hosts} but only have #{infra.hosts.count} hosts available.")
      add_flash(message, :error)
      $log.error(message)
    else
      scale_parameters_formatted = []
      return_message = _("Scaling")
      @count_parameters.each do |p|
        if !scale_parameters[p.name].nil? && scale_parameters[p.name] != p.value
          return_message += _(" #{p.name} from #{p.value} to #{scale_parameters[p.name]}")
          scale_parameters_formatted << {"name" => p.name, "value" => scale_parameters[p.name]}
        end
      end
      if scale_parameters_formatted.length > 0
        # A value was changed
        @stack.raw_update_stack(:parameters => scale_parameters_formatted)
        redirect_to :action => 'show', :id => params[:id], :flash_msg => return_message
      else
        # No values were changed
        add_flash(_("A value must be changed or provider will not be scaled."), :error)
      end
    end
  end

  private ############################
end
