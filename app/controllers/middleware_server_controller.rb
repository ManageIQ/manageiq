class MiddlewareServerController < ApplicationController
  include EmsCommon
  include MiddlewareCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  OPERATIONS = {
    :middleware_server_reload   => {:op   => :reload_middleware_server,
                                    :skip => true,
                                    :hawk => N_('reloading'),
                                    :msg  => N_('Reload')
  },
    :middleware_server_stop     => {:op   => :stop_middleware_server,
                                    :skip => true,
                                    :hawk => N_('stopping'),
                                    :msg  => N_('Stop')
    },
    :middleware_server_restart  => {:op   => :restart_middleware_server,
                                    :skip => true,
                                    :hawk => N_('restarting'),
                                    :msg  => N_('Restart')
    },
    :middleware_server_shutdown => {:op    => :shutdown_middleware_server,
                                    :skip  => true,
                                    :hawk  => N_('shutting down'),
                                    :msg   => N_('Shutdown'),
                                    :param => :timeout
    },
    :middleware_server_suspend  => {:op    => :suspend_middleware_server,
                                    :skip  => true,
                                    :hawk  => N_('suspending'),
                                    :msg   => N_('Suspend'),
                                    :param => :timeout
    },
    :middleware_server_resume   => {:op   => :resume_middleware_server,
                                    :skip => true,
                                    :hawk => N_('resuming'),
                                    :msg  => N_('Resume')
    },
    :middleware_add_deployment  => {:op    => :add_middleware_deployment,
                                    :skip  => false,
                                    :hawk  => N_('Not deploying to Hawkular server'),
                                    :msg   => N_('Deployment initiated for selected server(s)'),
                                    :param => :file
    }
  }.freeze

  def add_deployment
    selected_servers = identify_selected_entities

    params[:file] = {
      :file         => params["file"],
      :enabled      => params["enabled"],
      :runtime_name => params["runtimeName"]
    }
    run_server_operation(OPERATIONS.fetch(:middleware_add_deployment), selected_servers)

    render :update do |page|
      page << javascript_prologue
      page.replace("flash_msg_div", :partial => "layouts/flash_msg")
    end
  end

  def show
    return unless init_show
    case params[:display]
    when 'middleware_datasources' then show_middleware_entities(MiddlewareDatasource)
    when 'middleware_deployments' then show_middleware_entities(MiddlewareDeployment)
    else show_middleware
    end
  end

  def button
    selected_operation = params[:pressed].to_sym

    if OPERATIONS.key?(selected_operation)
      selected_servers = identify_selected_entities

      run_server_operation(OPERATIONS.fetch(selected_operation), selected_servers)

      javascript_flash
    else
      super
    end
  end

  def run_operation
    selected_servers = identify_selected_servers
    if selected_servers.nil?
      render :json => {:status => :error, :msg => _("No Servers selected")}
      return
    end

    operation = ('middleware_server_' + params["operation"]).to_sym
    if OPERATIONS.key?(operation)
      operation_info = OPERATIONS.fetch(operation)
      run_server_param_operation(operation_info, selected_servers)
    else
      msg = _("Unknown server operation: ") + operation
      render :json => {:status => :error, :msg => msg}
    end
  end

  private ############################

  # Identify the selected servers. When we got the call from the
  # single server page, we need to look at :id, otherwise from
  # the list of servers we need to query :miq_grid_checks
  def identify_selected_servers
    items = params[:miq_grid_checks]
    return items unless items.nil? || items.empty?

    params[:id]
  end

  def run_server_param_operation(operation_info, mw_servers)
    operation_triggered = false
    mw_servers.split(/,/).each do |mw_server|
      mw_server = identify_record mw_server

      if mw_server.product == 'Hawkular' && operation_info.fetch(:skip)
        skip_message = _("Not #{operation_info.fetch(:hawk)} the provider")
        render :json => {:status => :ok, :msg => skip_message}
      else
        operation_triggered = trigger_param_operation(operation_info, mw_server, :param)
      end
      if operation_triggered
        initiated_msg = _("#{operation_info.fetch(:msg)} initiated for selected server(s)")
        render :json => {:status => :ok, :msg => initiated_msg}
      end
    end
  end

  def trigger_param_operation(operation_info, mw_server, op_param)
    if operation_info.key? op_param
      name = operation_info.fetch(op_param) # which currently evaluates to :timeout
      val = params["timeout"]
      trigger_mw_operation operation_info.fetch(:op), mw_server, name => val
    else
      trigger_mw_operation operation_info.fetch(:op), mw_server
    end
    true
  end

  def run_server_operation(operation_info, items)
    if items.nil?
      add_flash(_("No servers selected"))
      return
    end

    operation_triggered = false
    items.split(/,/).each do |item|
      mw_server = identify_record item
      if mw_server.product == 'Hawkular' && operation_info.fetch(:skip)
        add_flash(_("Not %{hawkular_info} the provider") % {:hawkular_info => operation_info.fetch(:hawk)})
      else
        if operation_info.key? :param
          # Fetch param from UI - > see #9462/#8079
          name = operation_info.fetch(:param)
          val = params.fetch name || 0 # Default until we can really get it from the UI ( #9462/#8079)
          trigger_mw_operation operation_info.fetch(:op), mw_server, name => val
        else
          trigger_mw_operation operation_info.fetch(:op), mw_server
        end
        operation_triggered = true
      end
    end
    add_flash(_("#{operation_info.fetch(:msg)} initiated for selected server(s)")) if operation_triggered
  end

  def trigger_mw_operation(operation, mw_server, params = nil)
    mw_manager = mw_server.ext_management_system

    op = mw_manager.public_method operation
    if params
      op.call(mw_server.ems_ref, params)
    else
      op.call mw_server.ems_ref
    end
  end
end
