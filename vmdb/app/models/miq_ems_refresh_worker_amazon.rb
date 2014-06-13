class MiqEmsRefreshWorkerAmazon < MiqEmsRefreshWorker
  def self.ems_class
    EmsAmazon
  end
end
