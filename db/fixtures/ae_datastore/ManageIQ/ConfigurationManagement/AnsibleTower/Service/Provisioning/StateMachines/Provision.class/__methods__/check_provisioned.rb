#
# Description: This method checks to see if the job has been provisioned
# and refresh the job when it completes at the provider
#

class AnsibleTowerCheckProvisioned
  def initialize(handle)
    @handle = handle
  end

  def main
    @handle.log("info", "Starting Ansible Tower Provisioning")
    check_provisioned(task, service)
  end

  private

  def check_provisioned(task, service)
    # check whether the AnsibleTower job completed
    job = service.job

    if job.nil?
      @handle.root['ae_result'] = 'error'
      @handle.root['ae_reason'] = 'job was not created'
    else
      check_status(job)
    end

    unless @handle.root['ae_result'] == 'retry'
      @handle.log("info", "AnsibleTower job finished. Status: #{@handle.root['ae_result']}, reason: #{@handle.root['ae_reason']}")
      @handle.log("info", "Please examine job console output for more details") if @handle.root['ae_result'] == 'error'

      job.refresh_ems
      task.miq_request.user_message = @handle.root['ae_reason'].truncate(255) unless @handle.root['ae_reason'].blank?
    end
  end

  def check_status(job)
    status, reason = job.normalized_live_status
    case status.downcase
    when 'create_complete'
      @handle.root['ae_result'] = 'ok'
    when /failed$/, /canceled$/
      @handle.root['ae_result'] = 'error'
      @handle.root['ae_reason'] = reason
    else
      # job not done yet in provider
      @handle.root['ae_result']         = 'retry'
      @handle.root['ae_retry_interval'] = '1.minute'
    end
  end

  def task
    @handle.root["service_template_provision_task"].tap do |task|
      raise "service_template_provision_task not found" unless task
    end
  end

  def service
    task.destination.tap do |service|
      raise "service is not of type AnsibleTower" unless service.respond_to?(:job_template)
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  AnsibleTowerCheckProvisioned.new($evm).main
end
