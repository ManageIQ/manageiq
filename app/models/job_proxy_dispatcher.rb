class JobProxyDispatcher
  include Vmdb::Logging

  def self.dispatch
    new.dispatch
  end

  def initialize
    @zone = nil
  end

  def dispatch
    _, total_time = Benchmark.realtime_block(:total_time) do
    end

    _log.info("Complete - Timings: #{total_time.inspect}")
  end

  def self.waiting?
    Job.where(:state => "waiting_to_start")
  end

  def pending_jobs(job_class = VmScan)
    @zone = MiqServer.my_zone
    job_class.order(:id)
             .where(:state           => "waiting_to_start")
             .where(:dispatch_status => "pending")
             .where("zone is null or zone = ?", @zone)
             .where("sync_key is NULL or
                sync_key not in (
                  select sync_key from jobs where
                    dispatch_status = 'active' and
                    state != 'finished' and
                    (zone is null or zone = ?) and
                    sync_key is not NULL)", @zone)
  end

  def active_scans_by_zone(job_class, count = true)
    actives = Hash.new(0)
    jobs = job_class.where(:zone => @zone, :dispatch_status => "active")
              .where.not(:state => "finished")
    actives[@zone] = count ? jobs.count : jobs
    actives
  end
end # class JobProxyDispatcher
