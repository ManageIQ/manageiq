#
# Description: This method sends out retirement emails when the following events are raised:
#
# Events: stack_retire_warn, stack_retired, stack_entered_retirement
#
# Model Notes:
# 1. to_email_address - used to specify an email address in the case where the
#    vm's owner does not have an  email address. To specify more than one email
#    address separate email address with commas. (I.e. admin@example.com,user@example.com)
# 2. from_email_address - used to specify an email address in the event the
#    requester replies to the email
# 3. signature - used to stamp the email with a custom signature
#
stack = $evm.object['orchestration_stack']
if stack.nil?
  stack_id = $evm.object['orchestration_stack_id'].to_i
  stack = $evm.vmdb('orchestration_stack', stack_id) unless stack_id == 0
end

if stack.nil?
  stack = $evm.root['orchestration_stack']
  if stack.nil?
    stack_id = $evm.root['orchestration_stack_id'].to_i
    stack = $evm.vmdb('orchestration_stack', stack_id) unless stack_id == 0
  end
end

raise "Stack not specified" if stack.nil?

stack_name = stack['name']

event_type = $evm.object['event'] || $evm.root['event_type']

evm_owner_id = stack.attributes['evm_owner_id']
owner = nil
owner = $evm.vmdb('user', evm_owner_id) unless evm_owner_id.nil?

if owner
  to = owner.email
else
  to = $evm.object['to_email_address']
end

if event_type == "stack_retire_warn"

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "Stack Retirement Warning for #{stack_name}"

  body = "Hello, "
  body += "<br><br>Your stack: [#{stack_name}] will be retired on [#{stack['retires_on']}]."
  body += "<br><br>If you need to use this stack past this date please request an"
  body += "<br><br>extension by contacting Support."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

if event_type == "stack_entered_retirement"

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "Stack #{stack_name} has entered retirement"

  body = "Hello, "
  body += "<br><br>Your stack named [#{stack_name}] has been retired."
  body += "<br><br>You will have up to 3 days to un-retire this stack. Afterwhich time the stack will be deleted."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

if event_type == "stack_retired"

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "Stack Retirement Alert for #{stack_name}"

  body = "Hello, "
  body += "<br><br>Your stack named [#{stack_name}] has been retired."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"
end

$evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>") if @debug
$evm.execute('send_email', to, from, subject, body)
