#
# Description: This method is used to parse incoming Email Alerts
#

def dumpObjects
  return unless @debug
  # List all of the objects in the root object
  $evm.log("info", "===========================================")
  $evm.log("info", "In-storage ROOT Objects:")
  $evm.root.attributes.sort.each do |k, v|
    $evm.log("info", " -- \t#{k}: #{v}")
  end
  $evm.log("info", "===========================================")
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

$evm.log("info", "Root Object:<#{rootobj}> Detected")
$evm.root['object_type'] = rootobj 
