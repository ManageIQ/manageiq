class ServiceTemplateTransformationPlanTask < ServiceTemplateProvisionTask
  def self.base_model
    ServiceTemplateTransformationPlanTask
  end

  def self.get_description(req_obj)
    source_name = req_obj.source.name
    req_obj.kind_of?(ServiceTemplateTransformationPlanRequest) ? source_name : "Transforming VM [#{source_name}]"
  end

  def after_request_task_create
    update_attributes(:description => get_description)
  end

  def resource_action
    miq_request.source.resource_actions.detect { |ra| ra.action == 'Provision' }
  end

  def transformation_destination(source_obj)
    miq_request.transformation_mapping.destination(source_obj)
  end

  def pre_ansible_playbook_service_template
    ServiceTemplate.find_by(:id => vm_resource.options["pre_ansible_playbook_service_template_id"])
  end

  def post_ansible_playbook_service_template
    ServiceTemplate.find_by(:id => vm_resource.options["post_ansible_playbook_service_template_id"])
  end

  def update_transformation_progress(progress)
    options[:progress] = (options[:progress] || {}).merge(progress)
    save
  end

  def task_finished
    # update the status of vm transformation status in the plan
    vm_resource.update_attributes(:status => status == 'Ok' ? ServiceResource::STATUS_COMPLETED : ServiceResource::STATUS_FAILED)
  end

  def mark_vm_migrated
    source.tag_with("migrated", :ns => "/managed", :cat => "transformation_status")
  end

  def task_active
    vm_resource.update_attributes(:status => ServiceResource::STATUS_ACTIVE)
  end

  def conversion_host
    Host.find_by(:id => options[:transformation_host_id])
  end

  def transformation_log
    host = conversion_host
    if host.nil?
      msg = "Conversion host was not found: ID [#{options[:transformation_host_id]}]. Download of transformation log aborted."
      _log.error(msg)
      raise MiqException::Error, msg
    end

    userid, password = host.auth_user_pwd(:remote)
    if userid.blank? || password.blank?
      msg = "Credential was not found for host #{host.name}. Download of transformation log aborted."
      _log.error(msg)
      raise MiqException::Error, msg
    end

    logfile = options.fetch_path(:virtv2v_wrapper, "v2v_log")
    if logfile.blank?
      msg = "The location of transformation log was not set. Download of transformation log aborted."
      _log.error(msg)
      raise MiqException::Error, msg
    end

    begin
      require 'net/scp'
      Net::SCP.download!(host.ipaddress, userid, logfile, nil, :ssh => {:password => password})
    rescue Net::SCP::Error => scp_err
      _log.error("Download of transformation log for #{description} with ID [#{id}] failed with error: #{scp_err.message}")
      raise scp_err
    end
  end

  # Intend to be called by UI to display transformation log. The log is stored in MiqTask#task_results
  # Since the task_results may contain a large block of data, it is desired to remove the task upon receiving the data
  def transformation_log_queue(userid = nil)
    userid ||= User.current_userid || 'system'
    host = conversion_host
    if host.nil?
      msg = "Conversion host was not found: ID [#{options[:transformation_host_id]}]. Cannot queue the download of transformation log."
      return create_error_status_task(userid, msg).id
    end

    _log.info("Queuing the download of transformation log for #{description} with ID [#{id}]")
    options = {:userid => userid, :action => 'transformation_log'}
    queue_options = {:class_name  => self.class,
                     :method_name => 'transformation_log',
                     :instance_id => id,
                     :priority    => MiqQueue::HIGH_PRIORITY,
                     :args        => [],
                     :zone        => host.my_zone}
    MiqTask.generic_action_with_callback(options, queue_options)
  end

  def cancel
    update_attributes(:cancelation_status => MiqRequestTask::CANCEL_STATUS_REQUESTED)
  end

  def canceling
    update_attributes(:cancelation_status => MiqRequestTask::CANCEL_STATUS_PROCESSING)
  end

  def canceled
    update_attributes(:cancelation_status => MiqRequestTask::CANCEL_STATUS_FINISHED)
  end

  private

  def vm_resource
    miq_request.vm_resources.find_by(:resource => source)
  end

  def create_error_status_task(userid, msg)
    MiqTask.create(
      :name    => "Download transformation log with ID: #{id}",
      :userid  => userid,
      :state   => MiqTask::STATE_FINISHED,
      :status  => MiqTask::STATUS_ERROR,
      :message => msg
    )
  end
end
