module ManageIQ::Providers::StorageManager::CinderManager::RefreshParser::CrossLinkers
  def self.cross_link(ems, data)
    parent_manager = ems.parent_manager
    unless parent_manager
      _log.warn("Manager does not have a parent.")
      return
    end
    unless data
      _log.warn("Manager does not have volumes, snapshots, or volume backups.")
      return
    end

    parent_type = parent_manager.class.ems_type
    _log.debug("Parent type: #{parent_type}")

    require_nested parent_type.camelize
    const_get(parent_type.camelize.to_sym).new(parent_manager, data).cross_link
  end
end
