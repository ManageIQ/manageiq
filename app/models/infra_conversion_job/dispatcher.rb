class InfraConversionJob
  class Dispatcher < Job::Dispatcher
    def self.waiting?
      job_class.where(:state => "waiting_to_start").any?
    end

    def dispatch
      _, total_time = Benchmark.realtime_block(:total_time) do
        Benchmark.realtime_block(:v2v_dispatching) { dispatch_v2v_migrations }
        Benchmark.realtime_block(:v2v_limits) { apply_v2v_limits }
      end

      _log.info("Complete - Timings: #{total_time.inspect}")
    end
  end
end
