class MiqEmsRefreshWorkerOpenstackInfra < MiqEmsRefreshWorker
  def self.ems_class
    EmsOpenstackInfra
  end
end
