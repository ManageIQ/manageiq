class MiqServer::WorkerManagement
  include Vmdb::Logging

  require_nested :Kubernetes
  require_nested :Process
  require_nested :Systemd

  include_concern 'Dequeue'
  include_concern 'Monitor'

  MEMORY_EXCEEDED = :memory_exceeded
  NOT_RESPONDING  = :not_responding

  def self.build(my_server)
    klass = if MiqEnvironment::Command.is_podified?
              Kubernetes
            elsif MiqEnvironment::Command.supports_systemd?
              Systemd
            else
              Process
            end

    klass.new(my_server)
  end

  delegate :miq_workers, :to => :my_server
  attr_reader :my_server

  def initialize(my_server)
    @my_server = my_server
    @workers_lock        = Sync.new
    @workers             = {}
    @queue_messages_lock = Sync.new
    @queue_messages      = {}
  end

  def start_workers
    sync_config
    start_drb_server
    sync_workers
    wait_for_started_workers
  end

  def start_drb_server
    require 'drb'
    require 'drb/acl'

    acl = ACL.new(%w[deny all allow 127.0.0.1/32])
    DRb.install_acl(acl)

    require 'tmpdir'
    Dir::Tmpname.create("worker_monitor", nil) do |path|
      drb = DRb.start_service("drbunix://#{path}", self)
      FileUtils.chmod(0o750, path)
      my_server.update(:drb_uri => drb.uri)
    end
  end

  def worker_add(worker_pid)
    @workers_lock.synchronize(:EX) { @workers[worker_pid] ||= {} }
  end

  def worker_delete(worker_pid)
    @workers_lock.synchronize(:EX) { @workers.delete(worker_pid) }
  end
end
