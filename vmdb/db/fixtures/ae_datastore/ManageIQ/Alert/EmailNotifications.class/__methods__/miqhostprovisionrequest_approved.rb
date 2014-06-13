###################################
#
# EVM Automate Method: MiqHostProvisionRequest_Approved
#
# Notes: This method is used to email the provision requester that the
# Host provisioning request has been approved
#
# Events: request_approved
#
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    requester does not have a valid email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@company.com,user@company.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#
###################################
begin
  @method = 'MiqHostProvisionRequest_Approved'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # Get variables
  miq_request = $evm.root["miq_request"]

  # Override the default appliance IP Address below
  # appliance ||= 'evmserver.company.com'
  appliance ||= $evm.root['miq_server'].ipaddress

  ######################################
  #
  # Build email to requester with reason
  #
  ######################################
  $evm.log('info', "#{@method} - Requester email logic starting") if @debug

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
  subject = "Request ID #{miq_request.id} - Your host provisioning request was Approved, pending Quota Validation"

  # Build email body
  body = "Hello, "
  body += "<br>Your host request was approved. If Quota validation is successful you will be notified via email when the host is available."
  body += "<br><br>To view this Request go to: <a href='https://#{appliance}/miq_request/show/#{miq_request.id}'>https://#{appliance}/miq_request/show/#{miq_request.id}</a>"
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"

  #
  # Send email
  #
  $evm.log("info", "#{@method} - Sending email to <#{to}> from <#{from}> subject: <#{subject}>") if @debug
  $evm.execute(:send_email, to, from, subject, body)

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
