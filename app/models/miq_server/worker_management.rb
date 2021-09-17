class MiqServer::WorkerManagement
  include Vmdb::Logging

  include_concern 'Dequeue'
  include_concern 'Heartbeat'
  include_concern 'Monitor'

  attr_reader :my_server

  def initialize(my_server)
    @my_server = my_server
  end

  delegate :miq_workers, :to => :my_server

  def start_workers
    clean_heartbeat_files # Appliance specific
    sync_config
    start_drb_server
    sync_workers
    wait_for_started_workers
  end

  def setup_drb_variables
    @workers_lock        = Sync.new
    @workers             = {}

    @queue_messages_lock = Sync.new
    @queue_messages      = {}
  end

  def start_drb_server
    require 'drb'
    require 'drb/acl'

    setup_drb_variables

    acl = ACL.new(%w( deny all allow 127.0.0.1/32 ))
    DRb.install_acl(acl)

    require 'tmpdir'
    Dir::Tmpname.create("worker_monitor", nil) do |path|
      drb = DRb.start_service("drbunix://#{path}", self)
      FileUtils.chmod(0o750, path)
      my_server.update(:drb_uri => drb.uri)
    end
  end

  def worker_add(worker_pid)
    @workers_lock.synchronize(:EX) { @workers[worker_pid] ||= {} } unless @workers_lock.nil?
  end

  def worker_delete(worker_pid)
    @workers_lock.synchronize(:EX) { @workers.delete(worker_pid) } unless @workers_lock.nil?
  end
end
