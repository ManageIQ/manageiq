#
# Description: This method prepares arguments and parameters for a job template
#

$evm.log("info", "Starting Ansible Tower Pre-Provisioning")

task = $evm.root["service_template_provision_task"]
raise "service_template_provision_task not found" unless task

# service = task.destination

# Through service you can examine the job template, configuration manager (i.e., provider)
# and options to start a job
# You can also override these selections through service
