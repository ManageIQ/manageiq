module MiqProvisionSource
  def self.get_provisioning_request_source_class(src_type_string)
    case src_type_string
    when "CloudVolumeSnapshot"
      CloudVolumeSnapshot
    when "CloudVolume"
      CloudVolume
    else
      VmOrTemplate
    end
  end

  def self.get_provisioning_request_source(src_id, src_type_string)
    kls = get_provisioning_request_source_class(src_type_string)
    kls.find_by_id(src_id)
  end
end
