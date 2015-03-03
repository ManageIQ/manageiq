#
# Description: This method is used to add 14 days to retirement date when target
# VM has a retires_on value and is not already retired
#

vm_retire_extend_days = nil
vm_retire_extend_days ||= $evm.object['vm_retire_extend_days']
raise "ERROR - vm_retire_extend_days not found!" if vm_retire_extend_days.nil?

$evm.log("info", "Number of days to extend: <#{vm_retire_extend_days}>")

obj = $evm.object("process")

vm = obj["vm"] || $evm.root["vm"]
vm_name = vm.name

if vm.retires_on.nil? | vm.retires_on == ""
  $evm.log("info", "VM '#{vm_name}' has no retirement date - extension bypassed")
  exit MIQ_OK
end

if vm.retired
  $evm.log("info", "VM '#{vm_name}' already marked as retired. vm.retires_on date: #{vm.retires_on}. No Action taken")
  exit MIQ_OK
end

$evm.log("info", "VM: <#{vm_name}> current retirement date is #{vm.retires_on}")

unless vm.retires_on.nil?
  $evm.log("info", "Extending retirement <#{vm_retire_extend_days}> days for VM: <#{vm_name}>")

  # Set new retirement date here
  vm.retires_on += vm_retire_extend_days.to_i

  $evm.log("info", "VM: <#{vm_name}> new retirement date is #{vm.retires_on}")

  $evm.log("info", "Inspecting retirement: <#{vm.retirement.inspect}>")

  evm_owner_id = vm.attributes['evm_owner_id']
  owner = nil
  owner = $evm.vmdb('user', evm_owner_id) unless evm_owner_id.nil?
  $evm.log("info", "Inspecting VM Owner: #{owner.inspect}")

  if owner
    to = owner.email
  else
    to = $evm.object['to_email_address']
  end

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "VM Retirement Extended for #{vm_name}"

  body = "Hello, "
  body += "<br><br>The retirement date for your virtual machine: [#{vm_name}] has been extended to: [#{vm.retires_on}]."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"

  $evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
  $evm.execute('send_email', to, from, subject, body)
end
