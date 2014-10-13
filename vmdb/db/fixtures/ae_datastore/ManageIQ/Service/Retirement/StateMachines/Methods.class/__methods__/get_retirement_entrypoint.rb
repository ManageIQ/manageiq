$evm.log("info", "get_retirement_entrypoint starting")

$evm.log("info", "#{@method} - Listing Root Object Attributes:") 
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - \t#{k}: #{v}")  }
$evm.log("info", "#{@method} - ===========================================") 

# Get current provisioning status
service = $evm.root['service']
entry_point = service.automate_retirement_entrypoint
$evm.log("info", "get_retirement_entrypoint entry_point: #{entry_point} ")
if entry_point.blank?
  entry_point = '/Factory/StateMachines/ServiceRetirement/Default'
  $evm.log("info", "automate_retirement_entrypoint setting default entry_point to: #{entry_point} ")
end

parts = entry_point.split('/')
parts.shift  if entry_point[0,1]  == '/'          
retirement_instance    = parts.pop
retirement_class       = parts.pop
retirement_ns          = parts.join('/')

$evm.root['retirement_ns']       = retirement_ns
$evm.root['retirement_class']    = retirement_class
$evm.root['retirement_instance'] = retirement_instance

$evm.log("info", "get_retirement_entrypoint resulting entry_point: ns: #{retirement_ns} class: #{retirement_class} instance: #{retirement_instance} ")
