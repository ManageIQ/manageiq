#
# Description: This method sends out retirement emails when the following events are raised:
#
# Events: vm_retire_warn, vm_retired, vm_entered_retirement
#
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    vm's owner does not have an  email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@company.com,user@company.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#
vm = $evm.object['vm']
if vm.nil?
  vm_id = $evm.object['vm_id'].to_i
  vm = $evm.vmdb('vm', vm_id) unless vm_id == 0
end

if vm.nil?
  vm = $evm.root['vm']
  if vm.nil?
    vm_id = $evm.root['vm_id'].to_i
    vm = $evm.vmdb('vm', vm_id) unless vm_id == 0
  end
end

prov = $evm.root['miq_provision_request'] || $evm.root['miq_provision']
# if vm.nil?
#   vm = prov.vm unless prov.nil?
# end

vm = prov.vm if prov && vm.nil?

raise "User not specified" if vm.nil?

vm_name = vm['name']

event_type = $evm.object['event'] || $evm.root['event_type']

evm_owner_id = vm.attributes['evm_owner_id']
owner = nil
owner = $evm.vmdb('user', evm_owner_id) unless evm_owner_id.nil?

if owner
  to = owner.email
else
  to = $evm.object['to_email_address']
end

if event_type == "vm_retire_warn"

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "VM Retirement Warning for #{vm_name}"

  body = "Hello, "
  body += "<br><br>Your virtual machine: [#{vm_name}] will be retired on [#{vm['retires_on']}]."
  body += "<br><br>If you need to use this virtual machine past this date please request an"
  body += "<br><br>extension by contacting Support."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

if event_type == "vm_retire_extend"

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "VM Retirement Extended for #{vm_name}"

  body = "Hello, "
  body += "<br><br>Your virtual machine: [#{vm_name}] will now be retired on [#{vm['retires_on']}]."
  body += "<br><br>If you need to use this virtual machine past this date please request an"
  body += "<br><br>extension by contacting Support."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

if event_type == "vm_entered_retirement"

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "VM #{vm_name} has entered retirement"

  body = "Hello, "
  body += "<br><br>Your virtual machine named [#{vm_name}] has been retired."
  body += "<br><br>You will have up to 3 days to un-retire this VM. Afterwhich time the VM will be deleted."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

if event_type == "vm_retired"

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "VM Retirement Alert for #{vm_name}"

  body = "Hello, "
  body += "<br><br>Your virtual machine named [#{vm_name}] has been retired."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

$evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>") if @debug
$evm.execute('send_email', to, from, subject, body)
