RSpec.describe Job do
  context "With a single scan job," do
    before do
      @server1 = EvmSpecHelper.local_miq_server(:is_master => true)
      @server2 = FactoryBot.create(:miq_server, :zone => @server1.zone)

      @miq_server = EvmSpecHelper.local_miq_server(:is_master => true)
      @zone = @miq_server.zone
      @ems        = FactoryBot.create(:ems_vmware, :zone => @zone, :name => "Test EMS")
      @host       = FactoryBot.create(:host)

      @worker = FactoryBot.create(:miq_worker, :miq_server_id => @miq_server.id)
      @schedule_worker_settings = MiqScheduleWorker.worker_settings

      @vm       = FactoryBot.create(:vm_vmware, :ems_id => @ems.id, :host_id => @host.id)
      @job      = @vm.raw_scan
    end

    context "where job is dispatched but never started" do
      before do
        @job.update_attribute(:dispatch_status, "active")

        Timecop.travel 5.minutes

        Job.check_jobs_for_timeout
      end

      after do
        Timecop.return
      end

      context "after queue message is processed" do
        before do
          @msg = MiqQueue.get(:role => "smartstate", :zone => @zone.name)
          status, message, result = @msg.deliver
          @msg.delivered(status, message, result)

          @job.reload
        end

        it "should queue a timeout job if one not already on there" do
          expect { @job.timeout! }.to(change { MiqQueue.count }.by(1))
        end

        it "should be timed out after 5 minutes" do
          $log.info("@job: #{@job.inspect}")
          expect(@job.state).to eq("finished")
          expect(@job.status).to eq("error")
          expect(@job.message.starts_with?("job timed out after")).to be_truthy
        end
      end

      it "should not queue a timeout job if one is already on there" do
        expect { @job.timeout! }.not_to(change { MiqQueue.count })
      end

      it "should queue a timeout job if one is there, but it is failed" do
        MiqQueue.first.update(:state => MiqQueue::STATE_ERROR)
        expect { @job.timeout! }.to(change { MiqQueue.count }.by(1))
      end
    end

    context "where job is for a repository VM (no zone)" do
      before do
        @job.update(:state => "scanning", :dispatch_status => "active", :zone => nil)

        Timecop.travel 5.minutes

        Job.check_jobs_for_timeout

        @msg = MiqQueue.get(:role => "smartstate", :zone => @zone.name)
        status, message, result = @msg.deliver
        @msg.delivered(status, message, result)

        @job.reload
      end

      after do
        Timecop.return
      end

      it "should be timed out after 5 minutes" do
        $log.info("@job: #{@job.inspect}")
        expect(@job.state).to eq("finished")
        expect(@job.status).to eq("error")
        expect(@job.message.starts_with?("job timed out after")).to be_truthy
      end
    end

    context "where job is for a VM that disappeared" do
      before do
        @job.update(:state => "scanning", :dispatch_status => "active", :zone => nil)

        @vm.destroy

        Timecop.travel 5.minutes

        Job.check_jobs_for_timeout

        @msg = MiqQueue.get(:role => "smartstate", :zone => @zone.name)
        status, message, result = @msg.deliver
        @msg.delivered(status, message, result)

        @job.reload
      end

      after do
        Timecop.return
      end

      it "should be timed out after 5 minutes" do
        $log.info("@job: #{@job.inspect}")
        expect(@job.state).to eq("finished")
        expect(@job.status).to eq("error")
        expect(@job.message.starts_with?("job timed out after")).to be_truthy
      end
    end

    context "where 2 VMs in 2 Zones have an EVM Snapshot" do
      before do
        scan_type   = nil
        build       = '12345'
        description = "Snapshot for scan job: #{@job.guid}, EVM Server build: #{build} #{scan_type} Server Time: #{Time.now.utc.iso8601}"
        @snapshot = FactoryBot.create(:snapshot, :vm_or_template_id => @vm.id, :name => 'EvmSnapshot', :description => description)

        @zone2     = FactoryBot.create(:zone)
        @ems2      = FactoryBot.create(:ems_vmware, :zone => @zone2, :name => "Test EMS 2")
        @vm2       = FactoryBot.create(:vm_vmware, :ems_id => @ems2.id)
        @job2      = @vm2.raw_scan
        @job2.zone = @zone2.name
        description = "Snapshot for scan job: #{@job2.guid}, EVM Server build: #{build} #{scan_type} Server Time: #{Time.now.utc.iso8601}"
        @snapshot2 = FactoryBot.create(:snapshot, :vm_or_template_id => @vm2.id, :name => 'EvmSnapshot', :description => description)
      end

      it "should create proper AR relationships" do
        expect(@snapshot.vm_or_template).to eq(@vm)
        expect(@vm.snapshots.first).to eq(@snapshot)
        expect(@vm.ext_management_system).to eq(@ems)
        expect(@ems.vms.first).to eq(@vm)

        expect(@snapshot2.vm_or_template).to eq(@vm2)
        expect(@vm2.snapshots.first).to eq(@snapshot2)
        expect(@vm2.ext_management_system).to eq(@ems2)
        expect(@ems2.vms.first).to eq(@vm2)
      end

      it "should be able to find Job from Evm Snapshot" do
        job_guid, _ts = Snapshot.parse_evm_snapshot_description(@snapshot.description)
        expect(Job.find_by(:guid => job_guid)).to eq(@job)

        job_guid, _ts = Snapshot.parse_evm_snapshot_description(@snapshot2.description)
        expect(Job.find_by(:guid => job_guid)).to eq(@job2)
      end

      context "where job is not found and the snapshot timestamp is less than an hour old with default job_not_found_delay" do
        before do
          @job.destroy
          Job.check_for_evm_snapshots
        end

        it "should not create delete snapshot queue message" do
          assert_no_queue_message
        end
      end

      context "where job is not found and the snapshot timestamp is less than an hour old with job_not_found_delay from worker settings" do
        before do
          @job.destroy
          Job.check_for_evm_snapshots(@schedule_worker_settings[:evm_snapshot_delete_delay_for_job_not_found])
        end

        it "should not create delete snapshot queue message" do
          assert_no_queue_message
        end
      end

      context "where job is not found and the snapshot timestamp is more than an hour old with job_not_found_delay from worker settings" do
        before do
          @job.destroy
          Timecop.travel 61.minutes
          Job.check_for_evm_snapshots(@schedule_worker_settings[:evm_snapshot_delete_delay_for_job_not_found])
        end

        after do
          Timecop.return
        end

        it "should create delete snapshot queue message" do
          assert_queue_message
        end
      end

      context "where job is not found and job_not_found_delay passed with 5 minutes and the snapshot timestamp is more than an 5 minutes old" do
        before do
          @job.destroy
          Timecop.travel 6.minutes
          Job.check_for_evm_snapshots(5.minutes)
        end

        after do
          Timecop.return
        end

        it "should create delete snapshot queue message" do
          assert_queue_message
        end
      end

      context "where job is not found and the snapshot timestamp is nil" do
        before do
          @job.destroy
          @snapshot.update_attribute(:description, "Foo")
          Job.check_for_evm_snapshots
        end

        it "should create delete snapshot queue message" do
          assert_queue_message
        end
      end

      context "where job is active" do
        before do
          @job.update_attribute(:state, "active")
          Job.check_for_evm_snapshots
        end

        it "should not create delete snapshot queue message" do
          assert_no_queue_message
        end
      end

      context "where job is finished" do
        before do
          @job.update_attribute(:state, "finished")
          Job.check_for_evm_snapshots
        end

        it "should create delete snapshot queue message" do
          assert_queue_message

          Job.check_for_evm_snapshots

          assert_queue_message
        end
      end
    end

    context "where scan jobs exist for both vms and container images" do
      before do
        User.current_user = FactoryBot.create(:user)
        @ems_k8s = FactoryBot.create(
          :ems_kubernetes, :hostname => "test.com", :zone => @zone, :port => 8443,
          :authentications => [AuthToken.new(:name => "test", :type => 'AuthToken', :auth_key => "a secret")]
        )
        @image = FactoryBot.create(
          :container_image, :ext_management_system => @ems_k8s, :name => 'test',
          :image_ref => "docker://3629a651e6c11d7435937bdf41da11cf87863c03f2587fa788cf5cbfe8a11b9a"
        )
        @image_scan_job = @image.ext_management_system.raw_scan_job_create(@image.class, @image.id)
      end

      context "#target_entity" do
        it "returns the job target" do
          expect(@job.target_entity).to eq(@vm)
          expect(@image_scan_job.target_entity).to eq(@image)
        end
      end

      context "#timeout_adjustment" do
        it "returns the correct adjusment" do
          expect(@job.timeout_adjustment).to eq(1)
          expect(@image_scan_job.timeout_adjustment).to eq(1)
        end

        it "returns the correct adjusment 1 if target class was not defined" do
          job_without_target = VmScan.create_job(:target_class => nil)
          expect(job_without_target.timeout_adjustment).to eq(1)
        end
      end
    end

    describe "#timeout!" do
      it "adds to MiqQueue signal 'signal_abort' for this job " do
        @job.timeout!
        expect_signal_abort_and_timeout_message
      end
    end

    describe ".check_jobs_for_timeout" do
      before do
        @job.update(:state => "active")
        @queue_item = MiqQueue.put(:task_id => @job.guid)
      end

      after { Timecop.return }

      context "job timed out" do
        it "calls 'job#timeout!' if server was not assigned to job" do
          Timecop.travel 5.minutes
          Job.check_jobs_for_timeout
          expect_signal_abort_and_timeout_message
        end

        it "calls 'job#timeout!' if server was assigned to job but queue item not in 'ready' or 'dequeue' state" do
          @queue_item.update(:state => MiqQueue::STATE_WARN, :class_name => "MiqServer")
          @job.update(:miq_server_id => @server1.id)
          Timecop.travel 5.minutes
          Job.check_jobs_for_timeout
          expect_signal_abort_and_timeout_message
        end

        it "does not call 'job#timeout!' if queue state is 'ready' and server was assigned to job" do
          @queue_item.update(:state => MiqQueue::STATE_READY, :class_name => "MiqServer")
          @job.update(:miq_server_id => @server1.id)
          Timecop.travel 5.minutes
          Job.check_jobs_for_timeout
          expect_no_signal_abort
        end
      end

      context "job not timed out" do
        it "does not call 'job#timeout!'" do
          Job.check_jobs_for_timeout
          expect_no_signal_abort
        end
      end
    end
  end

  context "before_destroy callback" do
    before do
      @job = VmScan.create_job(:name => "Hello, World!")
    end

    it "allows to delete not active job" do
      expect(Job.count).to eq 1
      @job.destroy
      expect(Job.count).to eq 0
    end

    it "doesn't allows to delete active job" do
      @job.update!(:state => "Scanning")
      expect(Job.count).to eq 1
      @job.destroy
      expect(Job.count).to eq 1
    end
  end

  describe "#attributes_log" do
    it "returns attributes for logging" do
      job = VmScan.create_job(:name => "Hello, World!")
      expect(job.attributes_log).to include("VmScan", "Hello, World!", job.guid)
    end
  end

  context "belongs_to task" do
    let(:job_name) { "Hello, World!" }
    before do
      @job = VmScan.create_job(:name => job_name)
      @task = MiqTask.find_by(:name => job_name)
    end

    describe ".create_job" do
      it "creates job and corresponding task with the same name" do
        expect(@job.miq_task_id).to eq @task.id
      end
    end

    describe "#attributes_for_task" do
      it "returns hash with job's attributes to use for syncronization with linked task" do
        expect(@job.attributes_for_task).to include(
          :status        => "Ok",
          :state         => "Queued",
          :name          => job_name,
          :message       => "process initiated",
          :userid        => "system",
          :miq_server_id => nil,
          :context_data  => {},
          :zone          => nil,
          :started_on    => nil
        )
      end
    end

    context "after_update_commit callback calls" do
      describe "#update_linked_task" do
        it "executes when 'after_update_commit' callback triggered" do
          expect(@job).to receive(:update_linked_task)
          @job.save
        end

        it "updates 'context_data' attribute of miq_task if job's 'context' attribute was updated" do
          @job.update(:context => "some new context")
          expect(@task.reload.context_data).to eq "some new context"
        end

        it "updates 'started_on' attribute of miq_task if job's 'started_on' attribute was updated" do
          expect(@task.started_on).to be nil
          time = Time.new.utc.change(:usec => 0)
          @job.update(:started_on => time)
          expect(@task.reload.started_on).to eq time
        end

        it "updates 'zone' attribute of miq_task if job's 'zone' attribute updated" do
          @job.update(:zone => "Some Special Zone")
          expect(@task.reload.zone).to eq "Some Special Zone"
        end

        it "updates 'message' attribute of miq_task if job's 'message' attribute was updated" do
          @job.update(:message => "Some custom message for job")
          expect(@task.reload.message).to eq "Some custom message for job"
        end

        it "updates 'status' attribute of miq_task if job's 'status' attribute was updated" do
          @job.update(:status => "Custom status for job")
          expect(@task.reload.status).to eq "Custom status for job"
        end

        it "updates 'state' attribute of miq_task if job's 'state' attribute was updated" do
          @job.update(:state => "any status to trigger state update")
          expect(@task.reload.state).to eq "Any status to trigger state update"
        end
      end
    end
  end

  describe "#update_message" do
    let(:message) { "Very Interesting Message" }

    it "updates 'jobs.message' column" do
      VmScan.create_job.update_message(message)
      expect(Job.first.message).to eq message
    end
  end

  describe ".update_message" do
    let(:message) { "Very Interesting Message" }
    let(:guid) { "qwerty" }

    it "finds job by passed guid and updates 'message' column for found record" do
      VmScan.create_job(:guid => guid)
      Job.update_message(guid, message)
      expect(Job.find_by(:guid => guid).message).to eq message
    end
  end

  private

  def expect_signal_abort_and_timeout_message
    queue_item = MiqQueue.find_by(:instance_id => @job.id, :class_name => "Job", :method_name => "signal_abort")
    expect(queue_item.args[0].starts_with?("job timed out after")).to be true
  end

  def expect_no_signal_abort
    queue_item = MiqQueue.find_by(:instance_id => @job.id, :class_name => "Job", :method_name => "signal_abort")
    expect(queue_item).to be nil
  end

  def assert_queue_message
    expect(MiqQueue.count).to eq(1)
    q = MiqQueue.first
    expect(q.instance_id).to eq(@vm.id)
    expect(q.class_name).to eq(@vm.class.name)
    expect(q.method_name).to eq("remove_evm_snapshot")
    expect(q.args).to eq([@snapshot.id])
    expect(q.role).to eq("ems_operations")
    expect(q.zone).to eq(@zone.name)
  end

  def assert_no_queue_message
    expect(MiqQueue.count).to eq(0)
  end
end
