#
#            EVM Automate Method
#
$evm.log("info", "EVM Automate Method ConfigureChildDialog Started")
#
#            Method Code Goes here
#
$evm.log("info", "===========================================")
$evm.log("info", "Listing ROOT Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

stp_task = $evm.root["service_template_provision_task"]
$evm.log("info", "===========================================")
$evm.log("info", "Listing task Attributes:")
stp_task.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

$evm.log("info", "No child dialog options have been configured.")
exit MIQ_OK

dialog_service_type = $evm.root['dialog_service_type']
$evm.log("info", "User selected Dialog option = [#{dialog_service_type}]")

stp_miq_request_task = stp_task.miq_request_task
  # $evm.log("info","(parent) miq_request_task:  = [#{stp_miq_request_task}]")

stp_miq_request_tasks = stp_task.miq_request_tasks
  # $evm.log("info","(children) miq_request_tasks count:  = [#{stp_miq_request_tasks.count}]")

stp_miq_request_tasks.each do |t|
  $evm.log("info", " Setting dialog for: #{t.description}")
  service = t.source
  service_resource = t.service_resource
  # $evm.log("info"," Child service resource name: #{service_resource.resource_name}")
  # $evm.log("info"," Child service resource description: #{service_resource.resource_description}")

  service_tag_array = service.tags(:app_tier)
  service_tag = service_tag_array.first.to_s

  memory_size = nil

  case dialog_service_type
  when "Small"
    case service_tag
    when "app"
      memory_size = 1024
    when "web"
      memory_size = 1024
    when "db"
      memory_size = 4096
    else
      $evm.log("info", "Unknown Dialog type")
    end
  when "Large"
    case service_tag
    when "app"
      memory_size = 4096
    when "web"
      memory_size = 4096
    when "db"
      memory_size = 8192
    else
      $evm.log("info", "Unknown Dialog type")
    end
  else
    $evm.log("info", "Unknown Dialog type - setting Dialog options here")
  end

  t.set_dialog_option('memory', memory_size) unless memory_size.nil?

  $evm.log("info", "Set dialog for selection: [#{dialog_service_type}]  Service_Tier: [#{service_tag}] Memory size: [#{memory_size}]")
end
#
#
#
$evm.log("info", "EVM Automate Method ConfigureChildDialog Ended")
exit MIQ_OK
