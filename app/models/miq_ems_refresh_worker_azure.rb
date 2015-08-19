class MiqEmsRefreshWorkerAzure < MiqEmsRefreshWorker
  def self.ems_class
    EmsAzure
  end
end
