#
# Description: provide the dynamic list content from available images
#
module ManageIQ
  module Automate
    module Cloud
      module Orchestration
        module Operations
          class AvailableImages
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              fill_dialog_field(fetch_list_data)
            end

            private

            def fetch_list_data
              service = @handle.root.attributes["service_template"] || @handle.root.attributes["service"]
              miq_templates = service.try(:orchestration_manager).try(:miq_templates)

              image_list = {}
              if miq_templates
                miq_templates.each do |img|
                  os = img.hardware.try(:guest_os) || "unknown"
                  image_list[img.uid_ems] = "#{os} | #{img.name}"
                end
              end

              return nil => "<none>" if image_list.blank?

              image_list[nil] = "<select>" if image_list.length > 1
              image_list
            end

            def fill_dialog_field(list)
              dialog_field = @handle.object

              # sort_by: value / description / none
              dialog_field["sort_by"] = "description"

              # sort_order: ascending / descending
              dialog_field["sort_order"] = "ascending"

              # data_type: string / integer
              dialog_field["data_type"] = "string"

              # required: true / false
              dialog_field["required"] = "true"

              dialog_field["values"] = list
              dialog_field["default_value"] = list.length == 1 ? list.keys.first : nil
            end
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableImages.new.main
end
