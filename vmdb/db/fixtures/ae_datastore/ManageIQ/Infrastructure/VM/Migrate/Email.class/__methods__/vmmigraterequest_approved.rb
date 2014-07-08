#
# Description: This method is used to email the provision requester that
# VM provisioning request has been approved
#
# Events: request_approved
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    requester does not have a valid email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@company.com,user@company.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#

# Get miq_request object
miq_request = $evm.root["miq_request"]

# Override the default appliance IP Address below
appliance ||= $evm.root['miq_server'].ipaddress

# Build email to requester with reason
$evm.log('info', "Requester email logic starting")

# Get requester email
requester = $evm.root['miq_request'].requester

# Get to_email_address from requester.email then from model if nil
to = nil
to  = requester.email || $evm.object['to_email_address']

# Get from_email_address from model unless specified below
from = nil
from ||= $evm.object['from_email_address']

# Get signature from model unless specified below
signature = nil
signature ||= $evm.object['signature']

# Build subject
subject = "Request ID #{miq_request.id} - Your request to migrate Virtual Machine was Approved"

# Build email body
body = "Hello, "
body += "<br>Your Virtual Machine migration request was approved. You will be notified via email when the VM(s) have been migrated."
body += "<br><br>To view this Request go to: <a href='https://#{appliance}/miq_request/show/#{miq_request.id}'>https://#{appliance}/miq_request/show/#{miq_request.id}</a>"
body += "<br><br> Thank you,"
body += "<br> #{signature}"

$evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
$evm.execute(:send_email, to, from, subject, body)
