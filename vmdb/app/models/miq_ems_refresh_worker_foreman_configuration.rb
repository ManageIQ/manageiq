class MiqEmsRefreshWorkerForemanConfiguration < MiqEmsRefreshWorker
  def self.ems_class
    ConfigurationManagerForeman
  end
end
