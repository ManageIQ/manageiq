#
# Description: This method sends an e-mail when the following event is raised:
# Events: vm_provisioned
#
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    vm's owner does not have an  email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@company.com,user@company.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#

# Get vm from miq_provision object
prov = $evm.root['miq_provision']
vm = prov.vm
raise "VM not found" if vm.nil?

# Override the default appliance IP Address below
appliance ||= $evm.root['miq_server'].ipaddress

# Get VM Owner Name and Email
evm_owner_id = vm.attributes['evm_owner_id']
owner = nil
owner = $evm.vmdb('user', evm_owner_id) unless evm_owner_id.nil?
$evm.log("info", "VM Owner: #{owner.inspect}")

to = nil
to = owner.email unless owner.nil?
to ||= $evm.object['to_email_address']
if to.nil?
  $evm.log("info", "Email not sent because no recipient specified.")
  exit MIQ_OK
end

# Assign original to_email_Address to orig_to for later use
orig_to = to

# Get from_email_address from model unless specified below
from = nil
from ||= $evm.object['from_email_address']

# Get signature from model unless specified below
signature = nil
signature ||= $evm.object['signature']

subject = "Your virtual machine request has Completed - VM: #{vm['name']}"

body = "Hello, "

# Override email to VM owner and send email to a different email address
# if the template provisioned contains 'xx'
if prov.vm_template.name.downcase.include?('_xx_')
  $evm.log("info", "Setup of special email for DBMS VM")

  # Specify special email address below
  to      = 'evmadmin@company.com'

  body += "This email was sent by EVM to inform you of the provisioning of a new DBMS VM.<br>"
  body += "This new VM requires changes to DNS and DHCP to function correctly.<br>"
  body += "Please set the IP Address to static.<br>"
  body += "Once that has been completed, use this message to inform the "
  body += "requester that their new VM is ready.<br><br>"
  body += "-------------------------------- <br>"
  body += "Forward the message below to <br>"
  body += "#{orig_to}<br>"
  body += "-------------------------------- <br><br>"
  body += "<br>"
end

# VM Provisioned Email Body
body += "<br><br>Your request to provision a virtual machine was approved and completed on #{Time.now.strftime('%A, %B %d, %Y at %I:%M%p')}. "
body += "<br><br>Virtual machine #{vm['name']}<b> will be available in approximately 15 minutes</b>. "
body += "<br><br>For Windows VM access is available via RDP and for Linux VM access is available via putty/ssh, etc. Or you can use the Console Access feature found in the detail view of your VM. "
body += "<br><br>This VM will automatically be retired on #{vm['retires_on'].strftime('%A, %B %d, %Y')}, unless you request an extension. " if vm['retires_on'].respond_to?('strftime')
body += " You will receive a warning #{vm['reserved'][:retirement][:warn]} days before #{vm['name']} set retirement date." if vm['reserved'] && vm['reserved'][:retirement] && vm['reserved'][:retirement][:warn]
body += " As the designated owner you will receive expiration warnings at this email address: #{orig_to}"
body += "<br><br>If you are not already logged in, you can access and manage your virtual machine here <a href='https://#{appliance}/vm_or_template/show/#{vm['id']}'>https://#{appliance}/vm_or_template/show/#{vm['id']}'</a>"
body += "<br><br> If you have any issues with your new virtual machine please contact Support."
body += "<br><br> Thank you,"
body += "<br> #{signature}"

$evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
$evm.execute('send_email', to, from, subject, body)

