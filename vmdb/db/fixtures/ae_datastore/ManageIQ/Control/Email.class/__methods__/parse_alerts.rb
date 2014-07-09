###################################
#
# EVM Automate Method: Parse_Alerts
#
# Notes: This method is used to parse incoming Email Alerts
#
###################################
begin
  @method = 'Parse_Alerts'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  # Dump in-storage objects to the log
  def dumpObjects
    return unless @debug
    # List all of the objects in the root object
    $evm.log("info", "#{@method} ===========================================")
    $evm.log("info", "#{@method} In-storage ROOT Objects:")
    $evm.root.attributes.sort.each do |k, v|
      $evm.log("info", "#{@method} -- \t#{k}: #{v}")

      # $evm.log("info", "#{@method} Inspecting #{v}: #{v.inspect}")
    end
    $evm.log("info", "#{@method} ===========================================")
  end

  dumpObjects

  # List the types of object we will try to detect
  obj_types = {'vm' => 'vm', 'host' => 'host}', 'storage' => 'storage', 'ems_cluster' => 'ems_cluster', 'ext_management_system' => 'ext_management_system'}
  obj_type = $evm.root.attributes.detect { |k, v| k == obj_types[k] }

  # If obj_type is NOT nil else assume miq_server
  unless obj_type.nil?
    rootobj = obj_type.first
  else
    rootobj = 'miq_server'
  end

  $evm.log("info", "#{@method} - Root Object:<#{rootobj}> Detected")

  $evm.root['object_type'] = rootobj 

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
