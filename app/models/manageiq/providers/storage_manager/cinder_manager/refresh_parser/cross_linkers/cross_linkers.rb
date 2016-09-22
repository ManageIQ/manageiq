
module ManageIQ::Providers
  class StorageManager::CinderManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
  end
end

module ManageIQ::Providers::StorageManager::CinderManager::RefreshParser::CrossLinkers
	def self.cross_link(ems, data)
    parent_manager = ems.parent_manager
    _log.warn "Manager does not have a parent." unless parent_manager

    parent_type = parent_manager.class.ems_type
    _log.debug "Parent type: #{parent_type}"

    require_relative parent_type
    const_get(parent_type.camelize.to_sym).new(parent_manager, data).cross_link
  end
end
