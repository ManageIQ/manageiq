#
# Description: This method sends an e-mail when the following event is raised:
#
# Events: VmReconfig_Task_Complete
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    vm's owner does not have an  email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@example.com,user@example.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#

vm_id = $evm.root['vm_id']
vm = $evm.vmdb('vm', vm_id) unless vm_id == 0

raise "VM object not specified" if vm.nil?

$evm.log("info", "Reconfiguration of VM Completed - VM: #{vm['name']}")

evm_owner_id = vm['evm_owner_id']
owner = nil
owner = $evm.vmdb('user', evm_owner_id) unless evm_owner_id.nil?

# to_email_address from owner.email then from model if nil
to = owner.email || $evm.object['to_email_address']

# Get from_email_address from model unless specified below
from = nil
from ||= $evm.object['from_email_address']

# Get signature from model unless specified below
signature = nil
signature ||= $evm.object['signature']

subject = "Your virtual machine request has Completed - VM: #{vm['name']}"

body = "Hello, "

# VM Migration Email Body
body += "<br><br>Your request to Reconfigure virtual machine #{vm.name} was approved and completed. "
body += "<br><br> Thank you,"
body += "<br> #{signature}"

$evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
$evm.execute('send_email', to, from, subject, body)
