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
      job_class.where(:state => "waiting_to_start").any?
    end

    def dispatch
      raise NotImplementedError, _("Must be implemented in a subclass")
    end

    def zone
      @zone ||= Zone.find_by(:name => zone_name)
    end

    def zone_name
      @zone_name ||= MiqServer.my_zone
    end

    def pending_jobs
      job_class.order(:id)
               .where(:state           => "waiting_to_start")
               .where(:dispatch_status => "pending")
               .where("zone is null or zone = ?", zone_name)
               .where("sync_key is NULL or
                  sync_key not in (
                    select sync_key from jobs where
                      dispatch_status = 'active' and
                      state != 'finished' and
                      (zone is null or zone = ?) and
                      sync_key is not NULL)", zone_name)
    end

    def running_jobs
      job_class.order(:id)
               .where.not(:state => %w[finished waiting_to_start])
               .where("zone is null or zone = ?", zone_name)
               .where("sync_key is NULL or
                  sync_key not in (
                    select sync_key from jobs where
                      dispatch_status = 'active' and
                      state != 'finished' and
                      (zone is null or zone = ?) and
                      sync_key is not NULL)", zone_name)
    end
  end
end
