###################################
#
# EVM Automate Method: vm_retire_extend
#
# Notes: This method is used to add 14 days to retirement date when target
# VM has a retires_on value and is not already retired
#
###################################
begin
  @method = 'vm_retire_extend'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # Number of days to automatically extend retirement
  vm_retire_extend_days = nil
  vm_retire_extend_days ||= $evm.object['vm_retire_extend_days']
  raise "#{@method} - ERROR - vm_retire_extend_days not found!" if vm_retire_extend_days.nil?

  $evm.log("info", "#{@method} - Number of days to extend: <#{vm_retire_extend_days}>") if @debug

  obj = $evm.object("process")

  vm = obj["vm"] || $evm.root["vm"]
  vm_name = vm.name

  # Bail out if VM does not have retirement date
  if vm.retires_on.nil? | vm.retires_on == ""
    $evm.log("info", "#{@method} - VM '#{vm_name}' has no retirement date - extension bypassed") if @debug
    exit MIQ_OK
  end

  # If VM is already retired to do not continue
  if vm.retired
    $evm.log("info", "#{@method} - VM '#{vm_name}' is already marked as retired. vm.retires_on date value is  #{vm.retires_on}. No Action taken") if @debug
    # exit MIQ_OK
  end

  $evm.log("info", "#{@method} - VM: <#{vm_name}> current retirement date is #{vm.retires_on}") if @debug

  unless vm.retires_on.nil?
    $evm.log("info", "#{@method} - Extending retirement <#{vm_retire_extend_days}> days for VM: <#{vm_name}>") if @debug

    # Set new retirement date here
    vm.retires_on += vm_retire_extend_days.to_i

    $evm.log("info", "#{@method} - VM: <#{vm_name}> new retirement date is #{vm.retires_on}") if @debug

    # Resetting last warning
    # vm.retirement[:last_warn] = nil

    $evm.log("info", "#{@method} - Inspecting retirement: <#{vm.retirement.inspect}>") if @debug

    ######################################
    #
    # VM Retirement Exended Email
    #
    ######################################

    # Get VM Owner Name and Email
    evm_owner_id = vm.attributes['evm_owner_id']
    owner = nil
    owner = $evm.vmdb('user', evm_owner_id) unless evm_owner_id.nil?
    $evm.log("info", "#{@method} - Inspecting VM Owner: #{owner.inspect}") if @debug

    # to_email_address from owner.email then from model if nil
    unless owner.nil?
      to = owner.email
    else
      to = $evm.object['to_email_address']
    end

    # Get from_email_address from model unless specified below
    from = nil
    from ||= $evm.object['from_email_address']

    # Get signature from model unless specified below
    signature = nil
    signature ||= $evm.object['signature']

    # email subject
    subject = "VM Retirement Extended for #{vm_name}"

    # Build email body
    body = "Hello, "
    body += "<br><br>The retirement date for your virtual machine: [#{vm_name}] has been extended to: [#{vm.retires_on}]."
    body += "<br><br> Thank you,"
    body += "<br> #{signature}"

    #
    # Send email
    #
    $evm.log("info", "#{@method} - Sending email to <#{to}> from <#{from}> subject: <#{subject}>") if @debug
    $evm.execute('send_email', to, from, subject, body)
  end

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
