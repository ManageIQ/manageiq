class Job
  class Dispatcher
    include Vmdb::Logging

    def self.dispatch
      new.dispatch
    end

    def self.job_class
      module_parent
    end

    def self.waiting?
      job_class.where(:state => "waiting_to_start")
    end

    def dispatch
      raise NotImplementedError, _("Must be implemented in a subclass")
    end
  end
end
