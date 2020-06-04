class InfraConversionJob
  class Dispatcher < Job::Dispatcher
    def self.waiting?
      job_class.where(:state => "waiting_to_start").any?
    end

    def dispatch
    end
  end
end
