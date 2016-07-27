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
    run_operation(OPERATIONS.fetch(:middleware_add_deployment), selected_servers)

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

      run_operation(OPERATIONS.fetch(selected_operation),
                    selected_servers, "%{msg} initiated for selected server(s)")
      javascript_flash
    else
      super
    end
  end

  private ############################

end
