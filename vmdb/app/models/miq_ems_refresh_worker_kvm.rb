class MiqEmsRefreshWorkerKvm < MiqEmsRefreshWorker
  def self.ems_class
    EmsKvm
  end
end
