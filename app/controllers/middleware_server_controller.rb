class MiddlewareServerController < ApplicationController
  include EmsCommon
  include ContainersCommonMixin

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  OPERATIONS = {
    :middleware_server_reload => {:op   => :reload_middleware_server,
                                  :hawk => N_('Not reloading Hawkular server'),
                                  :msg  => N_('Reload initiated for selected server(s)')
    },
    :middleware_server_stop   => {:op   => :stop_middleware_server,
                                  :hawk => N_('Not stopping Hawkular server'),
                                  :msg  => N_('Stop initiated for selected server(s)')
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
      if mw_server.product == 'Hawkular'
        add_flash(operation_info.fetch(:hawk))
      else
        trigger_mw_operation operation_info.fetch(:op), mw_server
        operation_triggered = true
      end
    end
    add_flash(operation_info.fetch(:msg)) if operation_triggered
  end

  def trigger_mw_operation(operation, mw_server)
    mw_manager = mw_server.ext_management_system

    op = mw_manager.public_method operation
    op.call mw_server.ems_ref
  end
end
