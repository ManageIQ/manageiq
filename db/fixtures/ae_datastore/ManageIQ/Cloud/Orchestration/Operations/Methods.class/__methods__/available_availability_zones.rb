#
# Description: provide the dynamic list content from available availability zones
#
module ManageIQ
  module Automate
    module Cloud
      module Orchestration
        module Operations
          class AvailableAvailabilityZones
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              fill_dialog_field(fetch_list_data)
            end

            def fetch_list_data
              service = @handle.root.attributes["service_template"] || @handle.root.attributes["service"]
              av_zones = service.try(:orchestration_manager).try(:availability_zones)

              # avoid each_with_object method due to drb limitation
              az_list = {}
              av_zones.each { |az| az_list[az.ems_ref] = az.name } if av_zones

              return nil => "<none>" if az_list.blank?

              az_list[nil] = "<select>" if az_list.length > 1
              az_list
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
  ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableAvailabilityZones.new.main
end
