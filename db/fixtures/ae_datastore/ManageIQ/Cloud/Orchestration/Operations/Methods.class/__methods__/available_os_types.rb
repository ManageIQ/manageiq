#
# Description: provide the dynamic list content from available operating systems
#
module ManageIQ
  module Automate
    module Cloud
      module Orchestration
        module Operations
          class AvailableOsTypes
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              fill_dialog_field(fetch_selected_os)
            end

            private

            def fetch_selected_os
              selected_os = 'unknown'
              image_name = @handle.root["dialog_param_userImageName"]
              if image_name.present?
                selected_img = @handle.vmdb(:miq_template).find_by_uid_ems(image_name)
                selected_os = (selected_img.hardware.try(:guest_os) || "unknown").downcase
              end
              selected_os
            end

            def fill_dialog_field(selected_os)
              os_list = {'unknown' => '<Unknown>', 'linux' => 'Linux', 'windows' => 'Windows'}
              dialog_field = @handle.object

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
            end
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableOsTypes.new.main
end
