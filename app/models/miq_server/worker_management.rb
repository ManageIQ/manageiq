module MiqServer::WorkerManagement
  extend ActiveSupport::Concern

  include_concern 'Dequeue'
  include_concern 'Heartbeat'
  include_concern 'Monitor'

  included do
    has_many :miq_workers
  end

  module ClassMethods
    def kill_all_workers
      svr = my_server(true)
      svr.kill_all_workers unless svr.nil?
    end
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
      update(:drb_uri => drb.uri)
    end
  end

  def worker_add(worker_pid)
    @workers_lock.synchronize(:EX) { @workers[worker_pid] ||= {} } unless @workers_lock.nil?
  end

  def worker_delete(worker_pid)
    @workers_lock.synchronize(:EX) { @workers.delete(worker_pid) } unless @workers_lock.nil?
  end
end
