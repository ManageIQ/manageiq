puts("===========================================")
puts("Dumping Object")

puts("Args:    #{MIQ_ARGS.inspect}")

obj = $evm.object
puts("Listing Object Attributes:")
obj.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
puts("===========================================")

puts "Current Field Name: #{$evm.current_object.current_field_name}"
puts "Current Field Type: #{$evm.current_object.current_field_type}"
puts "Current Message:    #{$evm.current_object.current_message}"
puts "Current Namespace:  #{$evm.current_object.namespace}"
puts "Current Class:      #{$evm.current_object.class_name}"
puts "Current Instance:   #{$evm.current_object.instance_name}"
puts "Current Name:       #{$evm.current_object.name}"
puts "Current Object:     #{$evm.current_object}"

puts "calling $evm.vmdb(:host)"
h = $evm.vmdb(:host)
puts "$evm.vmdb(:host) >> #{h}"

puts "calling h.find_tagged_with"
hosts = h.find_tagged_with(:all => "/managed/function/citrix", :ns => "*")
puts "h.find_tagged_with >> #{hosts}"

exit MIQ_OK
