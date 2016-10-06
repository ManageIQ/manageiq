#
# Description: provide the dynamic list content from available availability zones
#
class AvailableAvailabilityZones
  def initialize(handle = $evm)
    @handle = handle
  end

  def main
    az_list = {}
    service = @handle.root.attributes["service_template"] || @handle.root.attributes["service"]
    if service.respond_to?(:orchestration_manager) && service.orchestration_manager
      service.orchestration_manager.availability_zones.each { |t| az_list[t.ems_ref] = t.name }
    end

    default_value = nil
    case az_list.length
    when 0
      az_list = {nil => "<none>"}
    when 1
      default_value = az_list.keys.first
    else
      az_list[nil] = "<select>"
    end

    dialog_field = @handle.object

    # sort_by: value / description / none
    dialog_field["sort_by"] = "description"

    # sort_order: ascending / descending
    dialog_field["sort_order"] = "ascending"

    # data_type: string / integer
    dialog_field["data_type"] = "string"

    # required: true / false
    dialog_field["required"] = "true"

    dialog_field["values"] = az_list
    dialog_field["default_value"] = default_value
  end
end

if __FILE__ == $PROGRAM_NAME
  AvailableAvailabilityZones.new.main
end
