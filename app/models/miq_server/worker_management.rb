class MiqServer::WorkerManagement
  include Vmdb::Logging

  MEMORY_EXCEEDED = :memory_exceeded
  NOT_RESPONDING  = :not_responding

  require_nested :Base
  require_nested :Kubernetes
  require_nested :Process
  require_nested :Systemd

  def self.build(my_server)
    Base.new(my_server)
  end
end
