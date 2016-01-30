#
# Description: provide the dynamic list content from available tenants
#
tenant_list = {nil => "<default>"}
service = $evm.root.attributes["service_template"] || $evm.root.attributes["service"]
if service.respond_to?(:orchestration_manager) && service.orchestration_manager
  service.orchestration_manager.cloud_tenants.each { |t| tenant_list[t.name] = t.name }
end

dialog_field = $evm.object

# sort_by: value / description / none
dialog_field["sort_by"] = "description"

# sort_order: ascending / descending
dialog_field["sort_order"] = "ascending"

# data_type: string / integer
dialog_field["data_type"] = "string"

# required: true / false
dialog_field["required"] = "false"

dialog_field["values"] = tenant_list
dialog_field["default_value"] = nil
