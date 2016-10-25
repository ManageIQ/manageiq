#
# Description: This method sends an e-mail when the following event is raised:
# Events: vm_provisioned
#
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    vm's owner does not have an  email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@example.com,user@example.com)
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

to = $evm.object['to']
signature = $evm.object['signature']

# VM Provisioned Email Body
body = "Hello,"
body += "<br><br>Your request to provision a Virtual Machine was approved and completed on "
body += "#{Time.zone.now.strftime('%A, %B %d, %Y at %I:%M%p')}. "
body += "<br><br>Virtual Machine #{vm['name']}<b> will be available in approximately 15 minutes</b>. "
body += "<br><br>For Windows VM access is available via RDP and for Linux VM access is available via putty/ssh, etc."
body += " Or you can use the Console Access feature found in the detail view of your VM. "
if vm['retires_on'].respond_to?('strftime')
  body += "<br><br>This VM will automatically be retired on #{vm['retires_on'].strftime('%A, %B %d, %Y')},"
  body += " unless you request an extension. "
end
if vm['reserved'] && vm['reserved'][:retirement] && vm['reserved'][:retirement][:warn]
  body += " You will receive a warning #{vm['reserved'][:retirement][:warn]} days before #{vm['name']} "
  body += "set retirement date."
end
body += " As the designated owner you will receive expiration warnings at this email address: #{to}"
body += "<br><br>If you are not already logged in, you can access and manage your Virtual Machine here <a "
body += "href='https://#{appliance}/vm_or_template/show/#{vm['id']}'>https://"
body += "#{appliance}/vm_or_template/show/#{vm['id']}'</a>"

body += "<br><br> If you have any issues with your new virtual machine please contact Support."
body += "<br><br> Thank you,"
body += "<br> #{signature}"
$evm.object['body'] = body
