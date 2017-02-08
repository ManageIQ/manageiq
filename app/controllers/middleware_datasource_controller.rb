class MiddlewareDatasourceController < ApplicationController
  include EmsCommon
  include MiddlewareCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  OPERATIONS = {
    :middleware_datasource_remove => { :op   => :remove_middleware_datasource,
                                       :hawk => N_('Not removed datasources'),
                                       :msg  => N_('The selected datasources were removed')
    }
  }.freeze

  def button
    selected_operation = params[:pressed].to_sym
    if OPERATIONS.key?(selected_operation)
      selected_ds = identify_selected_datasources
      run_datasource_operation(OPERATIONS.fetch(selected_operation), selected_ds)
      javascript_flash
    else
      super
    end
  end

  private ############################

  def identify_selected_datasources
    items = params[:miq_grid_checks]
    return items unless items.nil? || items.empty?
    params[:id]
  end

  def run_datasource_operation(operation_info, items)
    if items.nil?
      add_flash(_("No datasources selected"))
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
