class AvailableVdcNetworks
  def initialize(handle = $evm)
    @handle = handle
  end

  def main
    fill_dialog_field(fetch_list_data)
  end

  def fetch_list_data
    service = @handle.root.attributes["service_template"] || @handle.root.attributes["service"]
    vdc_networks = service.try(:orchestration_manager).try(:cloud_networks).try(:select) do |net|
      net.type == "ManageIQ::Providers::Vmware::NetworkManager::CloudNetwork::OrgVdcNet"
    end

    return nil => "<none>" if vdc_networks.blank?

    vdc_networks_list = { nil => "<select>" }
    vdc_networks.each { |net| vdc_networks_list[net.ems_ref] = net.name }

    vdc_networks_list
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

if __FILE__ == $PROGRAM_NAME
  AvailableVdcNetworks.new.main
end
