#
# Description: Set finished message for provision object.
#

prov_obj_name = $evm.root['vmdb_object_type']
@task = $evm.root[prov_obj_name]
final_message = "[#{$evm.root['miq_server'].name}] "

case $evm.root['vmdb_object_type']
when 'service_template_provision_task'
  final_message += "Service [#{@task.destination.name}] Provisioned Successfully"
when 'miq_provision'
  final_message += "VM [#{@task.get_option(:vm_target_name)}] "
  final_message += "IP [#{@task.vm.ipaddresses.first}] " if @task.vm && !@task.vm.ipaddresses.blank?
  final_message += "Provisioned Successfully"
else
  final_message += $evm.inputs['message']
end
@task.miq_request.user_message = final_message
@task.finished(final_message)
