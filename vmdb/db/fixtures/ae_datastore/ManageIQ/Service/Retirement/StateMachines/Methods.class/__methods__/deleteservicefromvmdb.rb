###################################
#
# EVM Automate Method: delete_from_vmdb
#
# Notes: This method removes the Service from the VMDB database
#
###################################
begin
  @method = 'delete_from_vmdb'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  service = $evm.root['service']
  category = "lifecycle"
  tag = "retire_full"

  if service
    $evm.log('info', "#{@method} - Deleting Service <#{service.name}> from VMDB") if @debug
    service.remove_from_vmdb
  end

  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
