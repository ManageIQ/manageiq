module ManageIQ::Providers
class BaseManager < ExtManagementSystem
  def ext_management_system
    self
  end

  def refresher
    if self.class::Refresher != BaseManager::Refresher
      self.class::Refresher
    else
      ::EmsRefresh::Refreshers.const_get("#{emstype.to_s.camelize}Refresher")
    end
  end
end
end

require_dependency 'manageiq/providers/base_manager/refresher'
