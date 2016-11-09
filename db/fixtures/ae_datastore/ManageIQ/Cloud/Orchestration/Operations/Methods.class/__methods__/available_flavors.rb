#
# Description: provide the dynamic list content from available flavors
#
module ManageIQ
  module Automate
    module Cloud
      module Orchestration
        module Operations
          class AvailableFlavors
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              fill_dialog_field(fetch_selected_os)
            end

            def fetch_selected_os
              flavor_list = {}
              service = $evm.root.attributes["service_template"] || $evm.root.attributes["service"]
              if service.respond_to?(:orchestration_manager) && service.orchestration_manager
                service.orchestration_manager.flavors.each { |f| flavor_list[f.name] = f.name }
              end
              flavor_list[nil] = flavor_list.empty? ? "<None>" : "<Choose>"


              service = @handle.root.attributes["service_template"] || @handle.root.attributes["service"]
              flavors = service.try(:orchestration_manager).try(:flavors)

              flavor_list = {}
              flavor_list.each { |f| flavor_list[f.name] = f.name } if flavors

              return nil => "<None>" if flavor_list.blank?

              flavor_list[nil] = "<Choose>" if flavor_list.length > 1
              flavor_list
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
              dialog_field["default_value"] = nil
            end
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  ManageIQ::Automate::Cloud::Orchestration::Operations::AvailableFlavors.new.main
end
