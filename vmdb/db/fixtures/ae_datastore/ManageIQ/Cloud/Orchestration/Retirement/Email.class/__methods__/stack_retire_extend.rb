#
# Description: This method is used to add 14 days to retirement date when target
# stack has a retires_on value and is not already retired
#

stack_retire_extend_days = nil
stack_retire_extend_days ||= $evm.object['stack_retire_extend_days']
raise "ERROR - stack_retire_extend_days not found!" if stack_retire_extend_days.nil?

$evm.log("info", "Number of days to extend: <#{stack_retire_extend_days}>")

obj = $evm.object("process")

stack = obj["orchestration_stack"] || $evm.root["orchestration_stack"]
stack_name = stack.name

if stack.retires_on.nil? | stack.retires_on == ""
  $evm.log("info", "Stack '#{stack_name}' has no retirement date - extension bypassed")
  exit MIQ_OK
end

if stack.retired
  $evm.log("info", "Stack '#{stack_name}' already marked as retired. stack.retires_on date: #{stack.retires_on}. No Action taken")
  exit MIQ_OK
end

$evm.log("info", "Stack: <#{stack_name}> current retirement date is #{stack.retires_on}")

unless stack.retires_on.nil?
  $evm.log("info", "Extending retirement <#{stack_retire_extend_days}> days for Stack: <#{stack_name}>")

  # Set new retirement date here
  stack.retires_on += stack_retire_extend_days.to_i

  $evm.log("info", "Stack: <#{stack_name}> new retirement date is #{stack.retires_on}")

  $evm.log("info", "Inspecting retirement: <#{stack.retirement.inspect}>")

  evm_owner_id = vm.attributes['evm_owner_id']
  owner = nil
  owner = $evm.vmdb('user', evm_owner_id) unless evm_owner_id.nil?
  $evm.log("info", "Inspecting Stack Owner: #{owner.inspect}")

  if owner
    to = owner.email
  else
    to = $evm.object['to_email_address']
  end

  from = nil
  from ||= $evm.object['from_email_address']

  signature = nil
  signature ||= $evm.object['signature']

  subject = "Stack Retirement Extended for #{stack_name}"

  body = "Hello, "
  body += "<br><br>The retirement date for your stack: [#{stack_name}] has been extended to: [#{stack.retires_on}]."
  body += "<br><br> Thank you,"
  body += "<br> #{signature}"

  $evm.log("info", "Sending email to <#{to}> from <#{from}> subject: <#{subject}>")
  $evm.execute('send_email', to, from, subject, body)
end
