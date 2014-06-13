module RufusSchedulerHelper
  RUFUS_NAPTIME = 0.01 # How long we give rufus to check for and fire eligible jobs

  def self.patch_for_job_callback
    return if @patched_rufus

    Rufus::Scheduler::Job.class_eval do
      alias __orig_trigger trigger
      def trigger(*args)
        __orig_trigger(*args).tap do |ret|
          ret.join if ret.kind_of?(Thread) # block until the work completes
          $rufus_job_completed = true
        end
      end
    end

    $rufus_job_completed = false
    @patched_rufus = true
  end

  def self.wait_for_job
    $rufus_job_completed = false
    yield
    sleep RUFUS_NAPTIME until $rufus_job_completed
  end
end
