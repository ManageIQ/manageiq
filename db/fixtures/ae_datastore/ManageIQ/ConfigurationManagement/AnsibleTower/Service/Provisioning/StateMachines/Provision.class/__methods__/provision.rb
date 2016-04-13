#
# Description: This method launches an Ansible job template
#

$evm.log("info", "Starting Ansible Tower Provisioning")

task = $evm.root["service_template_provision_task"]
raise "service_template_provision_task not found" unless task

service = task.destination
raise "service is not of type AnsibleTower" unless service.respond_to?(:job_template)
template = service.job_template

begin
  job = service.launch_job
  $evm.log("info", "Ansible Tower Job (#{job.name}) with reference id (#{job.ems_ref}) started.")
rescue => err
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = err.message
  task.miq_request.user_message = err.message.truncate(255)
  $evm.log("error", "Template #{template.name} launching failed. Reason: #{err.message}")
end
