#
# Description: This method is used to email the requester that the Service request was not auto-approved
#

def send_mail(to, from, subject, body)
  $evm.log(:info, "Sending email to #{to} from #{from} subject: #{subject}")
  $evm.execute(:send_email, to, from, subject, body)
end

def requester
  @miq_request.requester
end

def signature
  $evm.object['signature']
end

def reason
  @miq_request.reason
end

def approver_href(appliance)
  body = "<a href='https://#{appliance}/miq_request/show/#{@miq_request.id}'"
  body += ">https://#{appliance}/miq_request/show/#{@miq_request.id}</a>"
  body
end

def approver_text(appliance, requester_email)
  body = "Approver, "
  body += "<br>A Service request received from #{requester_email} is pending."
  body += "<br><br>Approvers notes: #{@miq_request.reason}"
  body += "<br><br>For more information you can go to: "
  body += approver_href(appliance)
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
  body
end

def requester_email_address
  owner_email = @miq_request.options.fetch(:owner_email, nil)
  email = requester.email || owner_email || $evm.object['to_email_address']
  $evm.log(:info, "To email: #{email}")
  email
end

def email_approver(appliance)
  $evm.log(:info, "Requester email logic starting")
  requester_email = requester_email_address
  to = $evm.object['to_email_address']
  from = $evm.object['from_email_address']
  subject = "Request ID #{@miq_request.id} - Service request was not approved"

  send_mail(to, from, subject, approver_text(appliance, requester_email))
end

def requester_href(appliance)
  body = "<a href='https://#{appliance}/miq_request/show/#{@miq_request.id}'>"
  body += "https://#{appliance}/miq_request/show/#{@miq_request.id}</a>"
end

def requester_text(appliance)
  body = "Hello, "
  body += "<br><br>Please review your Request and wait for approval from an Administrator."
  body += "<br><br>To view this Request go to: "
  body += requester_href(appliance)
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

def email_requester(appliance)
  $evm.log(:info, "Requester email logic starting")
  to = requester_email_address
  from = $evm.object['from_email_address']
  subject = "Request ID #{@miq_request.id} - Your Service Request was not Auto-Approved"

  send_mail(to, from, subject, requester_text(appliance))
end

@miq_request = $evm.root['miq_request']
$evm.log(:info, "miq_request id: #{@miq_request.id} approval_state: #{@miq_request.approval_state}")
$evm.log(:info, "options: #{@miq_request.options.inspect}")

service_template = $evm.vmdb(@miq_request.source_type, @miq_request.source_id)
$evm.log(:info, "service_template id: #{service_template.id} service_type: #{service_template.service_type}")
$evm.log(:info, "description: #{service_template.description} services: #{service_template.service_resources.count}")

appliance = $evm.root['miq_server'].ipaddress

email_requester(appliance)
email_approver(appliance)
