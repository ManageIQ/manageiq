module ManageIQ::Providers::CloudManager::Provision::VolumeAttachment
  def create_requested_volumes(_requested_volumes)
    raise NotImplementedError, _("Must be implemented in subclass")
  end

  def do_volume_creation_check(_volumes_refs)
    raise NotImplementedError, _("Must be implemented in subclass")
  end
end
