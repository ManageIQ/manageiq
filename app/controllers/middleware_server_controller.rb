class MiddlewareServerController < ApplicationController
  include EmsCommon
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  OPERATIONS = {
    :middleware_server_reload  => {:op    => :reload_middleware_server,
                                   :skip  => true,
                                   :hawk  => N_('reloading'),
                                   :msg   => N_('Reload')
    },
    :middleware_server_stop    => {:op    => :stop_middleware_server,
                                   :skip  => true,
                                   :hawk  => N_('stopping'),
                                   :msg   => N_('Stop')
    },
    :middleware_server_restart => {:op    => :restart_middleware_server,
                                   :skip  => true,
                                   :hawk  => N_('restarting'),
                                   :msg   => N_('Restart')
    },
    :middleware_server_shutdown => {:op   => :shutdown_middleware_server,
                                   :skip  => true,
                                   :hawk  => N_('shutting down'),
                                   :msg   => N_('Shutdown'),
                                   :param => ':timeout'
    },
    :middleware_server_suspend => {:op    => :suspend_middleware_server,
                                   :skip  => true,
                                   :hawk  => N_('suspending'),
                                   :msg   => N_('Suspend'),
                                   :param => ':timeout'
    },
    :middleware_server_resume  => {:op    => :resume_middleware_server,
                                   :skip  => true,
                                   :hawk  => N_('resuming'),
                                   :msg   => N_('Resume')
    },
    :middleware_server_jdr     => {:op    => :create_jdr_report,
                                   :skip  => false,
                                   :hawk  => nil, # not needed as skip is false
                                   :msg   => N_('JDR report creation initiated')
    }
  }.freeze

  def show_list
    process_show_list
  end

  def index
    redirect_to :action => 'show_list'
  end

  def show
    @display = params[:display] || "main" unless control_selected?
    @lastaction = "show"
    @showtype = "main"
    @record = identify_record(params[:id])
    show_container(@record, controller_name, display_name)
  end

  def listicon_image(item, _view)
    icon = item.decorate.try(:listicon_image)
    "svg/#{icon}.svg"
  end

  def button
    selected_operation = params[:pressed].to_sym

    if OPERATIONS.key?(selected_operation)
      selected_servers = identify_selected_servers

      run_server_operation(OPERATIONS.fetch(selected_operation), selected_servers)

      render :update do |page|
        page << javascript_prologue
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
      end
    else
      super
    end
  end

  private ############################

  def display_name
    _('Middleware Servers')
  end

  # Identify the selected servers. When we got the call from the
  # single server page, we need to look at :id, otherwise from
  # the list of servers we need to query :miq_grid_checks
  def identify_selected_servers
    items = params[:miq_grid_checks]
    return items unless items.nil? || items.empty?

    params[:id]
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
        add_flash(_("Not #{operation_info.fetch(:hawk)} the provider"))
      else
        if operation_info.key? :param
          # Fetch param from UI - > see #8079
          name = operation_info.fetch(:param)
          val = 0 # Default until we can really get it from the UI ( #8079)
          trigger_mw_operation operation_info.fetch(:op), mw_server, { name => val }
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
      op.call(mw_server.ems_ref,params)
    else
      op.call mw_server.ems_ref
    end
  end
end
