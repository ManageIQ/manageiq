###################################
#
# EVM Automate Method: GroupSequenceCheck
#
# Notes: This method checks to see if the task can be processed
#
###################################
begin
  @method = 'GroupSequenceCheck'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn on verbose logging
  @debug = true

  $evm.log("info", "#{@method} - Listing Root Object Attributes:") if @debug
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - \t#{k}: #{v}") if @debug }
  $evm.log("info", "#{@method} - ===========================================") if @debug

  # Get current provisioning status
  task = $evm.root['service_template_provision_task']

  # check if the task is in a runnable state, otherwise abort processing
  unless task.attributes['status'] == 'Ok'
    $evm.log('info', "#{@method} - Aborting due to task status: <#{task.status}>  task real status: <#{task.attributes['status']}> for Task: <#{task.id}> Description: <#{task.description}> state: <#{task.state}>.") if @debug
    exit MIQ_ABORT
  end

  result = task.group_sequence_run_now?
  $evm.log('info', "#{@method} group_sequence_run_now returned: <#{result}> for Task: <#{task.id}> Description: <#{task.description}> state: <#{task.state}> ") if @debug

  case result
  when false
    $evm.root['ae_result']         = 'retry'
    $evm.root['ae_retry_interval'] = '1.minute'
    $evm.log('info', "#{@method} - Service GroupSequenceCheck determined that it cannot run yet. Setting retry for task id: <#{task.id}> description: <#{task.description}> Parent task: <#{task.miq_request_id}> Parent description: <#{task.miq_request.description}> ") if @debug
  when true
    # Bump State
    $evm.root['ae_result'] = 'ok'
    $evm.log('info', "#{@method} - Service GroupSequenceCheck determined that it can run. Proceeding with task id: <#{task.id}> description: <#{task.description}>  Parent task: <#{task.miq_request_id}> Parent description: <#{task.miq_request.description}> ") if @debug
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
