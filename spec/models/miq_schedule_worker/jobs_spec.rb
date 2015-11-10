require 'spec_helper'

describe MiqScheduleWorker::Jobs do
  context "#ems_refresh_timer" do
    it "with no EMSes" do
      described_class.new.ems_refresh_timer(ManageIQ::Providers::Vmware::InfraManager)

      expect(MiqQueue.count).to eq(0)
    end

    it "with an EMS" do
      _, _, zone = EvmSpecHelper.create_guid_miq_server_zone
      FactoryGirl.create(:ems_vmware, :zone => zone)
      described_class.new.ems_refresh_timer(ManageIQ::Providers::Vmware::InfraManager)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first).to have_attributes(
        :class_name  => "ManageIQ::Providers::Vmware::InfraManager",
        :instance_id => nil,
        :method_name => "refresh_all_ems_timer",
        :zone        => zone.name
      )
    end
  end

  describe "#miq_schedule_queue_scheduled_work" do
    require "rufus-scheduler"

    it "delegates the queueing to MiqSchedule" do
      Timecop.freeze do
        schedule_id = 123
        scheduler = Rufus::Scheduler.new
        block = -> { "some work" }
        rufus_job = Rufus::Scheduler::EveryJob.new(scheduler, 1.hour, {}, block)

        expect(MiqSchedule).to receive(:queue_scheduled_work).with(schedule_id, rufus_job.job_id, 1.hour.from_now.to_i, {})

        described_class.new.miq_schedule_queue_scheduled_work(schedule_id, rufus_job)
      end
    end
  end
end
