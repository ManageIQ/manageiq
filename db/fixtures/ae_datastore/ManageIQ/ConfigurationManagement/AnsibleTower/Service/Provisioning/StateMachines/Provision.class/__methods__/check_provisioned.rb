#
# Description: This method checks to see if the job has been provisioned
#   and whether the refresh has completed
#
task = $evm.root["service_template_provision_task"]
raise "service_template_provision_task not found" unless task

service = task.destination
raise "service is not a type of AnsibleTower" unless service.respond_to?(:job)

# check whether the AnsibleTower job completed
job = service.job
status, reason = job.normalized_live_status
case status.downcase
when 'create_complete'
  $evm.root['ae_result'] = 'ok'
when /failed$/, /canceled$/
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = reason
else
  # deployment not done yet in provider
  $evm.root['ae_result']         = 'retry'
  $evm.root['ae_retry_interval'] = '1.minute'
end

unless $evm.root['ae_result'] == 'retry'
  $evm.log("info", "AnsibleTower job finished. Status: #{$evm.root['ae_result']}, reason: #{$evm.root['ae_reason']}")
  # $evm.log("info", "Please examine job resources for more details") if $evm.root['ae_result'] == 'error'

  job.refresh_ems
  task.miq_request.user_message = $evm.root['ae_reason'].truncate(255) unless $evm.root['ae_reason'].blank?
end
