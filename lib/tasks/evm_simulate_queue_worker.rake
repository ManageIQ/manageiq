namespace :evm do
  desc "Run a process that simulates a queue worker"
  task :simulate_queue_worker => :environment do
    class QueueSimulator
      include Vmdb::ConsoleMethods::LogLevelToggle
      include Vmdb::ConsoleMethods::SimulateQueueWorker
    end

    QueueSimulator.new.simulate_queue_worker
  end
end
