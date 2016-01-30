#
# Description: provide the dynamic list content from available operating systems
#
os_list = {'unknown' => '<Unknown>', 'linux' => 'Linux', 'windows' => 'Windows'}
selected_os = 'unknown'

image_name = $evm.root["dialog_param_userImageName"]
if image_name.present?
  selected_img = $evm.vmdb(:miq_template).find_by_uid_ems(image_name)
  selected_os = (selected_img.hardware.try(:guest_os) || "unknown").downcase
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

dialog_field["values"] = os_list
dialog_field["default_value"] = selected_os
