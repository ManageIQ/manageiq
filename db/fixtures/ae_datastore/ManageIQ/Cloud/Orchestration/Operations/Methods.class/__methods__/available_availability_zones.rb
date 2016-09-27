#
# Description: provide the dynamic list content from available resource groups
#
az_list = {}
service = $evm.root.attributes["service_template"] || $evm.root.attributes["service"]
if service.respond_to?(:orchestration_manager) && service.orchestration_manager
  service.orchestration_manager.availability_zones.each { |t| az_list[t.ems_ref] = t.name }
end

default_value = nil
case az_list.length
when 0
  az_list = {nil => "<none>"}
when 1
  default_value = az_list.keys.first
else
  az_list[nil] = "<select>"
end

dialog_field = $evm.object

# sort_by: value / description / none
dialog_field["sort_by"] = "description"

# sort_order: ascending / descending
dialog_field["sort_order"] = "ascending"

# data_type: string / integer
dialog_field["data_type"] = "string"

# required: true / false
dialog_field["required"] = "true"

dialog_field["values"] = az_list
dialog_field["default_value"] = default_value
