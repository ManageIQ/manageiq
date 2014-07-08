#
# Description: This method sends an e-mail when the following event is raised:
#
# Events: VmMigrateTask_Complete
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    vm's owner does not have an  email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@company.com,user@company.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#

# Look in the Root Object for the request
miq_task = $evm.root['vm_migrate_task']
miq_server = $evm.root['miq_server']

$evm.log("info", "Inspecting miq_task: #{miq_task.inspect}")

# Look in the current object for a VM
vm = $evm.object['vm']
if vm.nil?
  vm_id = $evm.object['vm_id'].to_i
  vm = $evm.vmdb('vm', vm_id) unless vm_id == 0
end

# Look in the Root Object for a VM
if vm.nil?
  vm = $evm.root['vm']
  if vm.nil?
    vm_id = $evm.root['vm_id'].to_i
    vm = $evm.vmdb('vm', vm_id) unless vm_id == 0
  end
end

if vm.nil?
  vm = miq_task.vm unless miq_task.nil?
end

raise "VM not found" if vm.nil?

# Get VM Owner Name and Email
evm_owner_id = vm.attributes['evm_owner_id']
owner = nil
owner = $evm.vmdb('user', evm_owner_id) unless evm_owner_id.nil?
$evm.log("info", "VM Owner: #{owner.inspect}")

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
body += "<br><br>Your request to migrate virtual machine #{vm.name} was approved and completed on #{Time.now.strftime('%A, %B %d, %Y at %I:%M%p')}. "
body += "<br><br>If you are not already logged in, you can access and manage your virtual machine here <a href='https://#{miq_server.ipaddress}/vm/show/#{vm['id']}'>https://#{miq_server.ipaddress}/vm/show/#{vm['id']}</a>"
body += "<br><br> Thank you,"
body += "<br> #{signature}"

$evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
$evm.execute('send_email', to, from, subject, body)
