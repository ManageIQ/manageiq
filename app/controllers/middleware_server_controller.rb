class MiddlewareServerController < ApplicationController
  include EmsCommon
  include MiddlewareCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  COMMON_OPERATIONS = {
    :middleware_server_reload  => {:op   => :reload_middleware_server,
                                   :skip => true,
                                   :hawk => N_('reloading'),
                                   :msg  => N_('Reload')
    },
    :middleware_server_suspend => {:op    => :suspend_middleware_server,
                                   :skip  => true,
                                   :hawk  => N_('suspending'),
                                   :msg   => N_('Suspend'),
                                   :param => :timeout
    },
    :middleware_server_resume  => {:op   => :resume_middleware_server,
                                   :skip => true,
                                   :hawk => N_('resuming'),
                                   :msg  => N_('Resume')
    },
  }.freeze

  STANDALONE_ONLY = {
    :middleware_server_stop     => {:op   => :stop_middleware_server,
                                    :skip => true,
                                    :hawk => N_('stopping'),
                                    :msg  => N_('Stop')
    },
    :middleware_server_shutdown => {:op    => :shutdown_middleware_server,
                                    :skip  => true,
                                    :hawk  => N_('shutting down'),
                                    :msg   => N_('Shutdown'),
                                    :param => :timeout
    },
    :middleware_server_restart  => {:op   => :restart_middleware_server,
                                    :skip => true,
                                    :hawk => N_('restarting'),
                                    :msg  => N_('Restart')
    },
    :middleware_add_deployment  => {:op    => :add_middleware_deployment,
                                    :skip  => false,
                                    :hawk  => N_('Not deploying to Hawkular server'),
                                    :msg   => N_('Deployment initiated for selected server(s)'),
                                    :param => :file
    },
    :middleware_add_jdbc_driver => {:op    => :add_middleware_jdbc_driver,
                                    :skip  => false,
                                    :msg   => N_('JDBC Driver installation'),
                                    :param => :driver
    },
    :middleware_add_datasource  => {:op    => :add_middleware_datasource,
                                    :skip  => false,
                                    :hawk  => N_('Not adding new datasource to Hawkular server'),
                                    :msg   => N_('New datasource initiated for selected server(s)'),
                                    :param => :datasource
    }
  }.freeze

  DOMAIN_ONLY = {
    :middleware_domain_server_start   => {:op   => :start_middleware_domain_server,
                                          :skip => true,
                                          :hawk => N_('starting'),
                                          :msg  => N_('Start')
    },
    :middleware_domain_server_stop    => {:op   => :stop_middleware_domain_server,
                                          :skip => true,
                                          :hawk => N_('stopping'),
                                          :msg  => N_('Stop')
    },
    :middleware_domain_server_restart => {:op   => :restart_middleware_domain_server,
                                          :skip => true,
                                          :hawk => N_('restarting'),
                                          :msg  => N_('Restart')
    },
    :middleware_domain_server_kill    => {:op   => :kill_middleware_domain_server,
                                          :skip => true,
                                          :hawk => N_('killing'),
                                          :msg  => N_('Kill')
    },
  }.freeze

  STANDALONE_SERVER_OPERATIONS = COMMON_OPERATIONS.merge(STANDALONE_ONLY)
  DOMAIN_SERVER_OPERATIONS = COMMON_OPERATIONS.merge(DOMAIN_ONLY)
  ALL_OPERATIONS = STANDALONE_SERVER_OPERATIONS.merge(DOMAIN_SERVER_OPERATIONS)

  def add_deployment
    selected_server = identify_selected_entities
    deployment_name = params["runtimeName"]

    existing_deployment = false
    if params["forceDeploy"] == 'false'
      existing_deployment = MiddlewareDeployment.find_by(:name => deployment_name, :server_id => selected_server)
    end

    if existing_deployment
      render :json => {
        :status => :warn, :msg => _("Deployment \"%s\" already exists on this server.") % deployment_name
      }
    else
      params[:file] = {
        :file         => params["file"],
        :enabled      => params["enabled"],
        :force_deploy => params["forceDeploy"],
        :runtime_name => params["runtimeName"]
      }
      run_server_operation(STANDALONE_SERVER_OPERATIONS.fetch(:middleware_add_deployment), selected_server)
      render :json => {
        :status => :success, :msg => _("Deployment \"%s\" has been initiated on this server.") % deployment_name
      }
    end
  end

  def add_jdbc_driver
    selected_server = identify_selected_entities

    params[:driver] = {
      :file                 => params["file"],
      :driver_name          => params["driverName"],
      :driver_jar_name      => params["driverJarName"],
      :module_name          => params["moduleName"],
      :driver_class         => params["driverClass"],
      :driver_major_version => params["majorVersion"],
      :driver_minor_version => params["minorVersion"]
    }

    run_server_operation(STANDALONE_SERVER_OPERATIONS.fetch(:middleware_add_jdbc_driver), selected_server)
    render :json => {
      :status => :success, :msg => _("JDBC Driver \"%s\" has been installed on this server.") % params["driverName"]
    }
  end

  def add_datasource
    datasource_name = params["datasourceName"]
    selected_server = identify_selected_entities
    existing_datasource = MiddlewareDatasource.find_by(:name => datasource_name, :server_id => selected_server)

    if existing_datasource
      render :json => {
        :status => :warn, :msg => _("Datasource \"%s\" already exists on this server.") % datasource_name
      }
    else
      params[:datasource] = {
        :datasourceName => datasource_name,
        :xaDatasource   => params["xaDatasource"],
        :jndiName       => params["jndiName"],
        :driverName     => params["driverName"],
        :driverClass    => params["driverClass"],
        :connectionUrl  => params["connectionUrl"]
      }

      run_server_operation(STANDALONE_SERVER_OPERATIONS.fetch(:middleware_add_datasource), selected_server)
      render :json => {
        :status => :success, :msg => _("Datasource \"%s\" has been installed on this server.") % params["datasource"]
      }
    end
  end

  def show
    return unless init_show
    case params[:display]
    when 'middleware_datasources' then show_middleware_entities(MiddlewareDatasource)
    when 'middleware_deployments' then show_middleware_entities(MiddlewareDeployment)
    when 'middleware_messagings' then show_middleware_entities(MiddlewareMessaging)
    else show_middleware
    end
  end

  def button
    selected_operation = params[:pressed].to_sym

    if ALL_OPERATIONS.key?(selected_operation)
      selected_servers = identify_selected_entities

      run_server_operation(ALL_OPERATIONS.fetch(selected_operation), selected_servers)

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
    if ALL_OPERATIONS.key?(operation)
      operation_info = ALL_OPERATIONS.fetch(operation)
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
      elsif mw_server.in_domain? && !DOMAIN_SERVER_OPERATIONS.value?(operation_info)
        skip_message = _("Not #{operation_info.fetch(:hawk)} the domain server")
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
    path = mw_server.ems_ref

    # in domain mode case we want to run the operation on the server-config DMR resource
    if mw_server.in_domain?
      path = path.sub(/%2Fserver%3D/, '%2Fserver-config%3D')
    end

    op = mw_manager.public_method operation
    if params
      op.call(path, params)
    else
      op.call(path)
    end
  end
end
