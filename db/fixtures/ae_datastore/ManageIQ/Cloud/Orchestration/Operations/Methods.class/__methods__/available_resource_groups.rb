#
# Description: provide the dynamic list content from available resource groups
#
module ManageIQ
  module Automate
    module Cloud
      module Orchestration
        module Operations
          class AvailableResoureceGroups
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              fill_dialog_field(fetch_list_data)
            end

            private

            def fetch_list_data
              service = @handle.root.attributes["service_template"] || @handle.root.attributes["service"]
              rs_groups = service.try(:orchestration_manager).try(:resource_groups)

              rs_list = {}
              rs_groups.each { |rs| rs_list[rs.name] = rs.name } if rs_groups

              return nil => "<none>" if rs_list.blank?

              rs_list[nil] = "<select>" if rs_list.length > 1
              rs_list
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
              dialog_field["required"] = "false"

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
  ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableResoureceGroups.new.main
end
