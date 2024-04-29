RSpec.describe MiqScheduleWorker::Jobs do
  context "#ems_refresh_timer" do
    it "with no EMSes" do
      described_class.new.ems_refresh_timer(ManageIQ::Providers::Vmware::InfraManager)

      expect(MiqQueue.count).to eq(0)
    end

    it "with an EMS" do
      zone = EvmSpecHelper.local_miq_server.zone
      FactoryBot.create(:ems_vmware, :zone => zone)
      described_class.new.ems_refresh_timer(ManageIQ::Providers::Vmware::InfraManager)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first).to have_attributes(
        :class_name  => "ManageIQ::Providers::Vmware::InfraManager",
        :instance_id => nil,
        :method_name => "refresh_all_ems_timer",
        :zone        => zone.name,
        :priority    => MiqQueue::MEDIUM_PRIORITY
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
        rufus_job = Rufus::Scheduler::EveryJob.new(scheduler, 1.hour.to_i, {}, block)

        expect(MiqSchedule).to receive(:queue_scheduled_work).with(schedule_id, rufus_job.job_id, 1.hour.from_now.to_i, {})

        described_class.new.miq_schedule_queue_scheduled_work(schedule_id, rufus_job)
      end
    end
  end

  describe "#generate_chargeback_for_service" do
    it "queue request to generate Chargeback reports for each service" do
      allow(MiqServer).to receive(:my_zone)
      described_class.new.generate_chargeback_for_service(:report_source => "Rspec - Chargeback reports queue")
      expect(MiqQueue.first).to have_attributes(
        :class_name  => "Service",
        :method_name => "queue_chargeback_reports",
        :args        => [{:report_source => "Rspec - Chargeback reports queue"}],
        :priority    => MiqQueue::MEDIUM_PRIORITY
      )
    end
  end

  describe "#check_for_timed_out_active_tasks" do
    it "enqueues update_status_for_timed_out_active_tasks" do
      allow(MiqServer).to receive(:my_zone)
      described_class.new.check_for_timed_out_active_tasks
      expect(MiqQueue.first).to have_attributes(
        :class_name  => "MiqTask",
        :method_name => "update_status_for_timed_out_active_tasks",
        :priority    => MiqQueue::MEDIUM_PRIORITY
      )
    end
  end

  it "#metric_capture_perf_capture_timer" do
    zone = EvmSpecHelper.local_miq_server.zone
    ems = FactoryBot.create(:ems_vmware, :zone => zone)
    described_class.new.metric_capture_perf_capture_timer
    expect(MiqQueue.first).to have_attributes(
      :class_name  => "Metric::Capture",
      :method_name => "perf_capture_timer",
      :args        => [ems.id],
      :priority    => MiqQueue::MEDIUM_PRIORITY
    )
  end

  context "with guid, server, zone" do
    let!(:server) { EvmSpecHelper.local_miq_server }
    let(:guid) { server.guid }
    let(:zone) { server.zone }

    context "queues for miq_server process" do
      it "#vmdb_database_connection_log_statistics" do
        described_class.new.vmdb_database_connection_log_statistics
        expect(MiqQueue.where(:method_name => "log_statistics").first).to have_attributes(:queue_name => "miq_server", :server_guid => guid, :zone => zone.name, :priority => MiqQueue::MEDIUM_PRIORITY)
      end

      it "#miq_server_audit_managed_resources" do
        described_class.new.miq_server_audit_managed_resources
        expect(MiqQueue.where(:method_name => "report_audit_details").first).to have_attributes(:queue_name => "miq_server", :server_guid => guid, :zone => zone.name, :priority => MiqQueue::MEDIUM_PRIORITY)
      end

      it "#miq_server_status_update" do
        described_class.new.miq_server_status_update
        expect(MiqQueue.where(:method_name => "status_update").first).to have_attributes(:queue_name => "miq_server", :server_guid => guid, :zone => zone.name, :priority => MiqQueue::HIGH_PRIORITY)
      end

      it "#miq_server_worker_log_status" do
        described_class.new.miq_server_worker_log_status
        expect(MiqQueue.where(:method_name => "log_status").first).to have_attributes(:queue_name => "miq_server", :server_guid => guid, :zone => zone.name, :priority => MiqQueue::HIGH_PRIORITY)
        expect(MiqQueue.where(:method_name => "log_status_all").first).to have_attributes(:queue_name => "miq_server", :server_guid => guid, :zone => zone.name, :priority => MiqQueue::HIGH_PRIORITY)
      end

      it "#vmdb_appliance_log_config" do
        described_class.new.vmdb_appliance_log_config
        expect(MiqQueue.where(:method_name => "log_config").first).to have_attributes(:queue_name => "miq_server", :server_guid => guid, :zone => zone.name, :priority => MiqQueue::MEDIUM_PRIORITY)
      end
    end

    describe "#job_check_for_evm_snapshots" do
      context "with no zones having an active smartstate role" do
        it "doesn't queue any work" do
          described_class.new.job_check_for_evm_snapshots(1.hour)
          expect(MiqQueue.count).to be_zero
        end
      end

      context "with a zone having an active smartstate role" do
        let(:role) { ServerRole.find_by(:name => "smartstate") || FactoryBot.create(:server_role, :name => 'smartstate', :max_concurrent => 0) }
        before do
          server.assign_role(role).update(:active => true)
        end

        it "queues the Job.check_for_evm_snapshots" do
          described_class.new.job_check_for_evm_snapshots(1.hour)
          expect(MiqQueue.count).to eq(1)
          expect(MiqQueue.where(:class_name => "Job", :method_name => "check_for_evm_snapshots").first).to have_attributes(:queue_name => "generic", :zone => zone.name, :priority => MiqQueue::MEDIUM_PRIORITY)
        end
      end
    end
  end
end
