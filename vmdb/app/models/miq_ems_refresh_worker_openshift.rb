class MiqEmsRefreshWorkerOpenshift < MiqEmsRefreshWorker
  def self.ems_class
    EmsOpenshift
  end
end
