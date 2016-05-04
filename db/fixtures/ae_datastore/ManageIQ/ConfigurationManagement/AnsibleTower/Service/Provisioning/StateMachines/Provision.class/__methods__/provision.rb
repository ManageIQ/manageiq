#
# Description: This method launches an Ansible Tower job template
#
class AnsibleTowerProvision
  def initialize(handle)
    @handle = handle
  end

  def main
    @handle.log("info", "Starting Ansible Tower Provisioning")
    run(task, service)
  end

  private

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

  def run(task, service)
    job = service.launch_job
    @handle.log("info", "Ansible Tower Job (#{job.name}) with reference id (#{job.ems_ref}) started.")
  rescue => err
    @handle.root['ae_result'] = 'error'
    @handle.root['ae_reason'] = err.message
    task.miq_request.user_message = err.message.truncate(255)
    @handle.log("error", "Template #{service.job_template.name} launching failed. Reason: #{err.message}")
  end
end

if __FILE__ == $PROGRAM_NAME
  AnsibleTowerProvision.new($evm).main
end
