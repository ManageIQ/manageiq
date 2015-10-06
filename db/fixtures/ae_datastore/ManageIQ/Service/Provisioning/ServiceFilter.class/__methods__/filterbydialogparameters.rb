# Description: This sample method allows the customer to control which services
#        get processed. By default it allows all services to be included
#        from the bundle. If the user wants to do be selective about which
#        services from a bundle get installed, they can copy this method and
#        apply custom logic
#
# This example is for bundled services, which is composed of multiple catalog items.
# The root service is always included.

# In this example we match the 'dialog_environment' to match the service_template name
# for a service to be included.
#

# Input Parameters:
#    $evm.root['service_template']  contains the current Service Template Object being evaluated
#    $evm.root['service']     contains the parent service object, will be nil if
#           this is the first service
#      $evm.root['service_template_provision_task']
#
# Output : The evm.root should have an attribute called include_service which is
#    evaluated by the internal state machine to decide if the service gets
#    included or excluded
#

$evm.root['include_service'] = false

service_template = $evm.root['service_template']
raise "service_template missing" unless service_template

service_template_provision_task = $evm.root['service_template_provision_task']
raise "service_template_provision_task missing" unless service_template_provision_task

miq_request = service_template_provision_task.miq_request
raise "service provision request missing" unless miq_request

$evm.log("info", "Request: #{miq_request.inspect}")

service = $evm.root['service']

# If this is the top level service with no parent, we include it
if service.nil?
  $evm.root['include_service'] = true
  $evm.log("info", "No parent service found, root service will be installed")
elsif service_template.service_type == 'composite'
  $evm.root['include_service'] = true
  $evm.log("info", "Composite service will be installed")
else
  service_template_tags = service_template.tags
  dialog_options = miq_request.options[:dialog]

  $evm.log("info", "dialog : #{dialog_options}")
  $evm.log("info", "tags   : #{service_template_tags}")
  raise "this example needs dialog_environment to filter services" unless dialog_options.key?('dialog_environment')

  # Add some custom filtering here based on dialog_options or tags
  # In this case we match the 'dialog_environment' to match the service_template name

  $evm.root['include_service'] = dialog_options["dialog_environment"].downcase == service_template.name.downcase
end

$evm.log("info", "Include Service: #{service_template.name} Value: #{$evm.root['include_service']}")

exit MIQ_OK
