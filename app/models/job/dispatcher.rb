class Job
  class Dispatcher
    include Vmdb::Logging

    def self.dispatch
      new.dispatch
    end

    def self.job_class
      module_parent
    end
    delegate :job_class, :to => :class

    def self.waiting?
      job_class.where(:state => "waiting_to_start")
    end

    def dispatch
      raise NotImplementedError, _("Must be implemented in a subclass")
    end

    def pending_jobs
      zone = MiqServer.my_zone

      job_class.order(:id)
               .where(:state           => "waiting_to_start")
               .where(:dispatch_status => "pending")
               .where("zone is null or zone = ?", zone)
               .where("sync_key is NULL or
                  sync_key not in (
                    select sync_key from jobs where
                      dispatch_status = 'active' and
                      state != 'finished' and
                      (zone is null or zone = ?) and
                      sync_key is not NULL)", zone)
    end
  end
end
