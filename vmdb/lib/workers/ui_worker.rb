require 'workers/worker_base'

class UiWorker < WorkerBase
  self.wait_for_worker_monitor = false

  # Do NOT process the signal that we use to terminate Mongrel
  def self.interrupt_signals
    INTERRUPT_SIGNALS - ['TERM']
  end

  def do_work
  end

  def do_before_work_loop
    @worker.release_db_connection
  end

  def self.start_worker(*args)
     cfg = {}
     opts = OptionParser.new
     self::OPTIONS_PARSER_SETTINGS.each do |key, desc, type|
       opts.on("--#{key} VAL", desc, type) {|v| cfg[key] = v}
     end
     opts.parse(*args)

     # Start the worker object
     self.new(cfg).start
  end
end
