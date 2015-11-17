#
# Description: provide the dynamic list content from available flavors
#
flavor_list = {}
service_template = $evm.root.attributes["service_template"]
if service_template.respond_to?(:orchestration_manager) && service_template.orchestration_manager
  service_template.orchestration_manager.flavors.each { |f| flavor_list[f.name] = f.name }
end
flavor_list[nil] = flavor_list.empty? ? "<None>" : "<Choose>"

dialog_field = $evm.object

# sort_by: value / description / none
dialog_field["sort_by"] = "description"

# sort_order: ascending / descending
dialog_field["sort_order"] = "ascending"

# data_type: string / integer
dialog_field["data_type"] = "string"

# required: true / false
dialog_field["required"] = "true"

dialog_field["values"] = flavor_list
dialog_field["default_value"] = nil
