class MiddlewareDeploymentController < ApplicationController
  include EmsCommon
  include MiddlewareCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  OPERATIONS = {
    :middleware_deployment_restart  => {
      :op       => :restart_middleware_deployment,
      :skip     => true,
      :hawk     => N_('restarting deployment'),
      :skip_msg => N_('Not %{operation_name} for %{record_name} on the provider itself'),
      :msg      => N_('Restart initiated for selected deployment(s)')
    },
    :middleware_deployment_disable  => {
      :op       => :disable_middleware_deployment,
      :skip     => true,
      :hawk     => N_('disabling deployment'),
      :skip_msg => N_('Not %{operation_name} for %{record_name} on the provider itself'),
      :msg      => N_('Disable initiated for selected deployment(s)')
    },
    :middleware_deployment_enable   => {
      :op       => :enable_middleware_deployment,
      :skip     => true,
      :hawk     => N_('enabling deployment'),
      :skip_msg => N_('Not %{operation_name} for %{record_name} on the provider itself'),
      :msg      => N_('Enable initiated for selected deployment(s)')
    },
    :middleware_deployment_undeploy => {
      :op       => :undeploy_middleware_deployment,
      :skip     => true,
      :hawk     => N_('undeploying deployment'),
      :skip_msg => N_('Not %{operation_name} for %{record_name} on the provider itself'),
      :msg      => N_('Undeployment initiated for selected deployment(s)')
    }
  }.freeze

  def self.operations
    OPERATIONS
  end

  def trigger_mw_operation(operation, mw_deployment, _params = nil)
    mw_manager = mw_deployment.ext_management_system
    op = mw_manager.public_method operation
    op.call(mw_deployment.ems_ref, mw_deployment.name)
  end

  menu_section :mdl
end
