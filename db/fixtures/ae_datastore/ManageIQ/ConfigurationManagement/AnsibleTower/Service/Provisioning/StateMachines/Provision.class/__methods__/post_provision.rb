#
# Description: This method examines the AnsibleTower job provisioned
#
$evm.log("info", "Starting Ansible Tower Post-Provisioning")

task = $evm.root["service_template_provision_task"].destination
raise "service_template_provision_task not found" unless task

service = task.destination
raise "service is not a type of AnsibleTower" unless service.respond_to?(:job)
#job = service.job

# You can add logic to process the job object in VMDB
# For example, dump all outputs from the job
#
# dump_job_outputs(job)
