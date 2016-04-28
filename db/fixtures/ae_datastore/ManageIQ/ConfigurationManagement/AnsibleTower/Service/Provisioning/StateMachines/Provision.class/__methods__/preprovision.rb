#
# Description: This method prepares arguments and parameters for a job template
#

$evm.log("info", "Starting Ansible Tower Pre-Provisioning")

task = $evm.root["service_template_provision_task"]
raise "service_template_provision_task not found" unless task

service = task.destination
raise "service is not of type AnsibleTower" unless service.respond_to?(:job_template)

# Through service you can examine the job template, configuration manager (i.e., provider)
# and options to start a job
# You can also override these selections through service
# $evm.log("info", "manager = #{service.configuration_manager.name}")
# $evm.log("info", "template = #{service.job_template.name}")

# Caution: job options may contain passwords.
# $evm.log("info", "job options = #{service.job_options.inspect}")

# Example how to programmatically modify job options:
# job_options = service.job_options
# job_options[:limit] = 'someHost'
# job_options[:extra_vars]['flavor'] = 'm1.small'
# # Important: set stack_options
# service.job_options = job_options
