class EmsPhysicalInfraController < ApplicationController
  include Mixins::GenericListMixin
  include Mixins::GenericShowMixin
  include EmsCommon        # common methods for EmsInfra/Cloud controllers
  include Mixins::EmsCommonAngular

  before_action :check_privileges
  before_action :get_session_data
  after_action :cleanup_action
  after_action :set_session_data

  def self.model
    ManageIQ::Providers::PhysicalInfraManager
  end

  def self.table_name
    @table_name ||= "ems_physical_infra"
  end

  def ems_path(*args)
    ems_physical_infra_path(*args)
  end

  def new_ems_path
    new_ems_physical_infra_path
  end

  def index
    redirect_to :action => 'show_list'
  end

  def register_nodes
    assert_privileges("host_register_nodes")
    redirect_to ems_physical_infra_path(params[:id], :display => "hosts") if params[:cancel]

    # Hiding the toolbars
    @in_a_form = true
    drop_breadcrumb(:name => _("Register Nodes"), :url => "/ems_physical_infra/register_nodes")

    @infra = ManageIQ::Providers::Openstack::InfraManager.find(params[:id])

    if params[:register]
      if params[:nodes_json].nil? || params[:nodes_json][:file].nil?
        log_and_flash_message(_("Please select a JSON file containing the nodes you would like to register."))
        return
      end

      begin
        uploaded_file = params[:nodes_json][:file]
        nodes_json = parse_json(uploaded_file)
        if nodes_json.nil?
          log_and_flash_message(_("JSON file format is incorrect, missing 'nodes'."))
        end
      rescue => ex
        log_and_flash_message(_("Cannot parse JSON file: %{message}") %
                                  {:message => ex})
      end

      if nodes_json
        begin
          @infra.workflow_service
        rescue => ex
          log_and_flash_message(_("Cannot connect to workflow service: %{message}") %
                                    {:message => ex})
          return
        end
        begin
          state, response = @infra.register_and_configure_nodes(nodes_json)
        rescue => ex
          log_and_flash_message(_("Error executing register and configure workflows: %{message}") %
                                    {:message => ex})
          return
        end
        if state == "SUCCESS"
          redirect_to ems_infra_path(params[:id],
                                     :display   => "hosts",
                                     :flash_msg => _("Nodes were added successfully. Refresh queued."))
        else
          log_and_flash_message(_("Unable to add nodes: %{error}") % {:error => response})
        end
      end
    end
  end

  def ems_physical_infra_form_fields
    ems_form_fields
  end

  private

  ############################
  # Special EmsCloud link builder for restful routes
  def show_link(ems, options = {})
    ems_path(ems.id, options)
  end

  def log_and_flash_message(message)
    add_flash(message, :error)
    $log.error(message)
  end

  def update_stack(stack, stack_parameters, provider_id, return_message, operation, additional_args = {})
    begin
      # Check if stack is ready to be updated
      update_ready = stack.update_ready?
    rescue => ex
      log_and_flash_message(_("Unable to update stack, obtaining of status failed: %{message}") %
                            {:message => ex})
      return
    end

    if !update_ready
      add_flash(_("Provider stack is not ready to be updated, another operation is in progress."), :error)
    elsif !stack_parameters.empty?
      # A value was changed
      begin
        stack.raw_update_stack(nil, stack_parameters)
        if operation == 'scaledown'
          @stack.queue_post_scaledown_task(additional_args[:services])
        end
        redirect_to ems_infra_path(provider_id, :flash_msg => return_message)
      rescue => ex
        log_and_flash_message(_("Unable to initiate scaling: %{message}") % {:message => ex})
      end
    else
      # No values were changed
      add_flash(_("A value must be changed or provider stack will not be updated."), :error)
    end
  end

  def verify_hosts_for_scaledown(hosts)
    has_invalid_nodes = false
    error_return_message = _("Not all hosts can be removed from the deployment.")

    hosts.each do |host|
      unless host.maintenance
        has_invalid_nodes = true
        error_return_message += _(" %{host_uid_ems} needs to be in maintenance mode before it can be removed ") %
                                {:host_uid_ems => host.uid_ems}
      end
      if host.number_of(:vms) > 0
        has_invalid_nodes = true
        error_return_message += _(" %{host_uid_ems} needs to be evacuated before it can be removed ") %
                                {:host_uid_ems => host.uid_ems}
      end
      unless host.name.include?('Compute')
        has_invalid_nodes = true
        error_return_message += _(" %{host_uid_ems} is not a compute node ") % {:host_uid_ems => host.uid_ems}
      end
    end

    return has_invalid_nodes, error_return_message
  end

  def restful?
    true
  end
  public :restful?

  def parse_json(uploaded_file)
    JSON.parse(uploaded_file.read)["nodes"]
  end

  menu_section :inf
end
