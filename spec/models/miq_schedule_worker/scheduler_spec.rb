require 'rufus/scheduler'

RSpec.describe MiqScheduleWorker::Scheduler do
  let(:logger) { double("Logger") }
  let(:schedules) { [] }
  let(:rufus_scheduler) { Rufus::Scheduler.new }
  let(:scheduler) { described_class.new(logger, schedules, rufus_scheduler)}

  after { rufus_scheduler.shutdown(:kill) }

  describe "#schedule_every" do
    it "accepts just string time" do
      Timecop.freeze do
        scheduler.schedule_every("3h") {}
        job = rufus_scheduler.jobs.first
        expect(job.next_time).to eq(3.hours.from_now)
      end
    end

    it "accepts ruby options" do
      Timecop.freeze do
        work = lambda {}
        scheduler.schedule_every(3.hours, :first_in => 1.hour, :tags => [:first, :tag], &work)
        job = rufus_scheduler.jobs.first
        expect(job.next_time).to eq(1.hours.from_now)
        expect(job.tags).to match_array(%w(first tag))
        expect(job.callable).to eq(work)
      end
    end

    it "accepts string options" do
      Timecop.freeze do
        scheduler.schedule_every("3h", :first_in => "1h") {}
        job = rufus_scheduler.jobs.first
        expect(job.next_time).to eq(1.hours.from_now)
      end
    end

    it "adds a job to rufus's collection of all jobs" do
      scheduler.schedule_every("3h") {}
      job = rufus_scheduler.jobs.first
      expect(rufus_scheduler.jobs).to eq([job])
    end

    it "adds to the list of scheduled jobs" do
      scheduler.schedule_every("3h") {}
      job = rufus_scheduler.jobs.first
      expect(schedules).to eq([job])
    end

    context "with different parmeters" do
      it "interprets first arg nil as trigger to skip scheduling" do
        expect(logger).to receive(:warn).once.with(/Duration is empty, scheduling ignored/)
        scheduler.schedule_every(nil) {}
      end

      it "catches an error on 0 first arg" do
        expect(logger).to receive(:error).once.with(/scheduler_spec.rb/)
        scheduler.schedule_every(0) {}
      end

      it "works on nil :first_in" do
        expect(logger).not_to receive(:error)
        scheduler.schedule_every(1, :first_in => nil) {}
      end
    end
  end

  describe "#schedule_cron" do
    it "returns the job" do
      work = lambda {}
      scheduler.schedule_cron("0 0 * * *", :tags => [:a, :b], &work)
      job = rufus_scheduler.jobs.first

      expect(job.rough_frequency).to eq(1.day.to_i)
      expect(job.tags).to match_array(%w(a b))
      expect(job.callable).to eq(work)
    end

    it "adds to the list of scheduled jobs" do
      scheduler.schedule_cron("0 0 * * *") {}
      job = rufus_scheduler.jobs.first

      expect(schedules).to eq([job])
    end

    it "adds a job to rufus's collection of all jobs" do
      scheduler.schedule_cron("0 0 * * *") {}
      job = rufus_scheduler.jobs.first

      expect(rufus_scheduler.jobs).to eq([job])
    end
  end
end
