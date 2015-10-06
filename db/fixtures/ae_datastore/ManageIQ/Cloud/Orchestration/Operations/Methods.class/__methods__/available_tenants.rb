#
# Description: provide the dynamic list content from available tenants
#
tenant_list = {nil => "default"}
service_template = $evm.root.attributes["service_template"]
if service_template.respond_to?(:orchestration_manager) && service_template.orchestration_manager
  service_template.orchestration_manager.cloud_tenants.each { |t| tenant_list[t.name] = t.name }
end

dialog_field = $evm.object

# sort_by: value / description / none
dialog_field["sort_by"] = "value"

# sort_order: ascending / descending
# dialog_field["sort_order"] = "ascending"

# data_type: string / integer
dialog_field["data_type"] = "string"

# required: true / false
# dialog_field["required"] = "true"

dialog_field["values"] = tenant_list
dialog_field["default_value"] = nil
