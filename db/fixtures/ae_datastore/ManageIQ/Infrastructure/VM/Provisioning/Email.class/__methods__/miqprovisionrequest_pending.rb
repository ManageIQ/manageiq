#
# Description: This method is launched from the not_approved method which raises the requst_pending event
# when the provisioning request is NOT auto-approved
# Events: request_pending
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    requester does not have a valid email address.To specify more than one email
#    address separate email address with commas. (I.e. admin@company.com,user@company.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#

# Build email to requester with reason
def emailrequester(miq_request, appliance, msg)
  $evm.log("info", "Requester email logic starting")

  # Get requester object
  requester = miq_request.requester

  # Get requester email else set to nil
  requester_email = requester.email || nil

  # Get Owner Email else set to nil
  owner_email = miq_request.options[:owner_email] || nil
  $evm.log("info", "Requester email:<#{requester_email}> Owner Email:<#{owner_email}>")

  # if to is nil then use requester_email or owner_email
  to = nil
  to ||= requester_email # || owner_email

  # If to is still nil use to_email_address from model
  to ||= $evm.object['to_email_address']

  # Get from_email_address from model unless specified below
  from = nil
  from ||= $evm.object['from_email_address']

  # Get signature from model unless specified below
  signature = nil
  signature ||= $evm.object['signature']

  # Set email subject
  subject = "Request ID #{miq_request.id} - Your Request for a new VM(s) was not Auto-Approved"

  # Build email body
  body = "Hello, "
  body += "<br>#{msg}."
  body += "<br><br>Please review your Request and update or wait for approval from an Administrator."
  body += "<br><br>To view this Request go to: "
  body += "<a href='https://#{appliance}/miq_request/show/#{miq_request.id}'>https://#{appliance}/miq_request/show/#{miq_request.id}</a>"
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"

  $evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
  $evm.execute(:send_email, to, from, subject, body)
end

# Build email to approver with reason
def emailapprover(miq_request, appliance, msg, provisionRequestApproval)
  $evm.log("info", "Approver email logic starting")

  # Get requester object
  requester = miq_request.requester

  # Get requester email else set to nil
  requester_email = requester.email || nil

  # Get Owner Email else set to nil
  owner_email = miq_request.options[:owner_email] || nil
  $evm.log("info", "Requester email:<#{requester_email}> Owner Email:<#{owner_email}>")

  # Override to email address below or get to_email_address from from model
  to = nil
  to  ||= $evm.object['to_email_address']

  # Override from_email_address below or get from_email_address from model
  from = nil
  from ||= $evm.object['from_email_address']

  # Get signature from model unless specified below
  signature = nil
  signature ||= $evm.object['signature']

  # Set email subject
  if provisionRequestApproval
    subject = "Request ID #{miq_request.id} - Virtual machine request was not approved"
  else
    subject = "Request ID #{miq_request.id} - Virtual Machine request was denied due to quota limitations"
  end

  # Build email body
  body = "Approver, "
  body += "<br>A request received from #{requester_email} is pending."
  body += "<br><br>#{msg}."
  body += "<br><br>Approvers notes: #{miq_request.reason}" if provisionRequestApproval
  body += "<br><br>For more information you can go to: <a href='https://#{appliance}/miq_request/show/#{miq_request.id}'>https://#{appliance}/miq_request/show/#{miq_request.id}</a>"
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"

  $evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
  $evm.execute(:send_email, to, from, subject, body)
end

# Get miq_request from root
miq_request = $evm.root['miq_request']
raise "miq_request missing" if miq_request.nil?
$evm.log("info", "Detected Request:<#{miq_request.id}> with Approval State:<#{miq_request.approval_state}>")

# Override the default appliance IP Address below
appliance = nil
appliance ||= $evm.root['miq_server'].ipaddress

# Get incoming message or set it to default if nil
msg = miq_request.resource.message || "Request pending"

# Check to see which state machine called this method
if msg.downcase.include?('quota')
  provisionRequestApproval = false
else
  provisionRequestApproval = true
end

# Email Requester
emailrequester(miq_request, appliance, msg)

# Email Approver
emailapprover(miq_request, appliance, msg, provisionRequestApproval)
