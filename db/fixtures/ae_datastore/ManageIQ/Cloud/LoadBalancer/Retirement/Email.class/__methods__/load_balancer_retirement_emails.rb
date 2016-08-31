#
# Description: This method sends out retirement emails when the following events are raised:
#
# Events: load_balancer_retire_warn, load_balancer_retired, load_balancer_entered_retirement
#
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    vm's owner does not have an  email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@example.com,user@example.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#
load_balancer = $evm.object['load_balancer']
if load_balancer.nil?
  load_balancer_id = $evm.object['load_balancer_id'].to_i
  load_balancer = $evm.vmdb('load_balancer', load_balancer_id) unless load_balancer_id == 0
end

if load_balancer.nil?
  load_balancer = $evm.root['load_balancer']
  if load_balancer.nil?
    load_balancer_id = $evm.root['load_balancer_id'].to_i
    load_balancer = $evm.vmdb('load_balancer', load_balancer_id) unless load_balancer_id == 0
  end
end

raise "LoadBalancer not specified" if load_balancer.nil?

load_balancer_name = load_balancer['name']

event_type = $evm.object['event'] || $evm.root['event_type']

evm_owner_id = load_balancer.attributes['evm_owner_id']
owner = nil
owner = $evm.vmdb('user', evm_owner_id) unless evm_owner_id.nil?

if owner
  to = owner.email
else
  to = $evm.object['to_email_address']
end

if event_type == "load_balancer_retire_warn"

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "LoadBalancer Retirement Warning for #{load_balancer_name}"

  body = "Hello, "
  body += "<br><br>Your load_balancer: [#{load_balancer_name}] will be retired on [#{load_balancer['retires_on']}]."
  body += "<br><br>If you need to use this load_balancer past this date please request an"
  body += "<br><br>extension by contacting Support."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

if event_type == "load_balancer_entered_retirement"

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "LoadBalancer #{load_balancer_name} has entered retirement"

  body = "Hello, "
  body += "<br><br>Your load_balancer named [#{load_balancer_name}] has been retired."
  body += "<br><br>You will have up to 3 days to un-retire this load_balancer. Afterwhich time the load_balancer will be deleted."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

if event_type == "load_balancer_retired"

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "LoadBalancer Retirement Alert for #{load_balancer_name}"

  body = "Hello, "
  body += "<br><br>Your load_balancer named [#{load_balancer_name}] has been retired."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

$evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>") if @debug
$evm.execute('send_email', to, from, subject, body)
