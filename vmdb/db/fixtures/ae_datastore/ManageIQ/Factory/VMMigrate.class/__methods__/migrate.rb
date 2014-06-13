###################################
#
# EVM Automate Method: Migrate
#
# Notes: This method launches the migration job
#
###################################
begin
  @method = 'Migrate'
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Started")

  $evm.root["vm_migrate_task"].execute

  #
  # Exit method
  #
  $evm.log("info", "===== EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "<#{@method}>: [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
