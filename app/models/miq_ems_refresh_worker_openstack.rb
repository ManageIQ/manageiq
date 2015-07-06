class MiqEmsRefreshWorkerOpenstack < MiqEmsRefreshWorker
  def self.ems_class
    EmsOpenstack
  end
end
