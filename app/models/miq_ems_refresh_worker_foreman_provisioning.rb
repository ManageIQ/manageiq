class MiqEmsRefreshWorkerForemanProvisioning < MiqEmsRefreshWorker
  def self.ems_class
    ProvisioningManagerForeman
  end
end
