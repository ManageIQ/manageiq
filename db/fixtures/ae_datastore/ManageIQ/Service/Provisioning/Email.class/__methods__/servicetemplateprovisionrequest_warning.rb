#
# Description: This method is used to email the requester and approver that the service
# request Quota warning threshold has been reached.
#

def send_mail(to, from, subject, body)
  $evm.log(:info, "Sending email to #{to} from #{from} subject: #{subject}")
  $evm.execute(:send_email, to, from, subject, body)
end

def requester
  @miq_request.requester
end

def requester_email_address
  owner_email = @miq_request.options.fetch(:owner_email, nil)
  email = requester.email || owner_email || $evm.object['to_email_address']
  $evm.log(:info, "Requester email: #{email}")
  email
end

def signature
  $evm.object['signature']
end

def reason
  @miq_request.reason
end

def approver_text(appliance, requester_email, msg)
  body = "Approver, "
  body += "<br>A service request received from #{requester_email} is approaching their quota."
  body += "<br><br>#{msg}."
  body += "<br><br>For more information you can go to: "
  body += "<br><br><a href='https://#{appliance}/miq_request/show/#{@miq_request.id}'</a>"
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
  body
end

def email_approver(appliance, msg)
  $evm.log(:info, "Approver email logic starting")

  to = $evm.object['to_email_address']
  from = $evm.object['from_email_address']
  $evm.log(:info, "To email:<#{to}>")

  subject = "Request ID #{@miq_request.id} - Warning service request quota is approaching threshold"
  send_mail(to, from, subject, approver_text(appliance, requester_email_address, msg))
end

def requester_text(appliance, msg)
  body = "Hello, "
  body += "<br>#{msg}."
  body += "<br><br>For more information you can go to: "
  body += "<br><br><a href='https://#{appliance}/miq_request/show/#{@miq_request.id}'"
  body += ">https://#{appliance}/miq_request/show/#{@miq_request.id}</a>"
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
  body
end

def email_requester(appliance, msg)
  $evm.log(:info, "Requester email logic starting")
  to = requester_email_address
  from = $evm.object['from_email_address']
  subject = "Request ID #{@miq_request.id} - Warning your service request quota is approaching threshold"

  send_mail(to, from, subject, requester_text(appliance, msg))
end

@miq_request = $evm.root['miq_request']
$evm.log(:info, "miq_request id: #{@miq_request.id} approval_state: #{@miq_request.approval_state}")
$evm.log(:info, "options: #{@miq_request.options.inspect}")

service_template = $evm.vmdb(@miq_request.source_type, @miq_request.source_id)
$evm.log(:info, "service_template id: #{service_template.id} service_type: #{service_template.service_type}")
$evm.log(:info, "description: #{service_template.description} services: #{service_template.service_resources.count}")

appliance = $evm.root['miq_server'].ipaddress

msg = @miq_request.get_option(:service_quota_warn_exceeded) ||
      @miq_request.resource.message ||
      "Request Quota Warning"

email_requester(appliance, msg)
email_approver(appliance, msg)
