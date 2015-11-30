#
# Description: provide the dynamic list content from available images
#
image_list = {}
service = $evm.root.attributes["service_template"] || $evm.root.attributes["service"]
if service.respond_to?(:orchestration_manager) && service.orchestration_manager
  service.orchestration_manager.miq_templates.each do |img|
    os = img.hardware.try(:guest_os) || "unknown"
    image_list[img.uid_ems] = "#{os} | #{img.name}"
  end
end
if image_list.empty?
  image_list[nil] = "<None>"
elsif image_list.size > 1
  image_list[nil] = "<Choose>"
else
  default_value = image_list.first.first
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

dialog_field["values"] = image_list
dialog_field["default_value"] = default_value
