class MiqEmsRefreshWorkerKubernetes < MiqEmsRefreshWorker
  def self.ems_class
    EmsKubernetes
  end
end
