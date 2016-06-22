class MiddlewareDeploymentController < ApplicationController
  include EmsCommon
  include ContainersCommonMixin
  include MiddlewareCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  OPERATIONS = {
    :middleware_deployment_redeploy => {:op   => :redeploy_middleware_deployment,
                                        :hawk => N_('Not redeploying deployment'),
                                        :msg  => N_('Redeployment initiated for selected deployment(s)')
    },
    :middleware_deployment_undeploy => {:op   => :undeploy_middleware_deployment,
                                        :hawk => N_('Not undeploying deployment'),
                                        :msg  => N_('Undeployment initiated for selected deployment(s)')
    }
  }.freeze

  def show
    clear_topology_breadcrumb
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype = "main"
    @record = identify_record(params[:id])
    show_container(@record, controller_name, display_name)
  end

  def button
    selected_operation = params[:pressed].to_sym
    if OPERATIONS.key?(selected_operation)
      selected_archives = identify_selected_deployments
      run_deployment_operation(OPERATIONS.fetch(selected_operation), selected_archives)
      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    else
      super
    end
  end

  private ############################

  # Identify the selected deployments. When we got the call from the
  # single deployment page, we need to look at :id, otherwise from
  # the list of deployments we need to query :miq_grid_checks
  def identify_selected_deployments
    items = params[:miq_grid_checks]
    return items unless items.nil? || items.empty?
    params[:id]
  end

  def run_deployment_operation(operation_info, items)
    if items.nil?
      add_flash(_("No deployments selected"))
      return
    end
    operation_triggered = false
    items.split(/,/).each do |item|
      mw_server = identify_record item
      trigger_mw_operation operation_info.fetch(:op), mw_server
      operation_triggered = true
    end
    add_flash(operation_info.fetch(:msg)) if operation_triggered
  end

  def trigger_mw_operation(operation, mw_server)
    mw_manager = mw_server.ext_management_system
    op = mw_manager.public_method operation
    op.call mw_server.ems_ref
  end
end
