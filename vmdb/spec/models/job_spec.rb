require "spec_helper"

describe Job do
  context "With a single scan job," do

    before(:each) do
      @guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)

      @zone       = FactoryGirl.create(:zone)
      @miq_server = FactoryGirl.create(:miq_server, :guid => @guid, :zone => @zone)
      MiqServer.stub(:my_server).and_return(@miq_server)
      @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone, :name => "Test EMS")
      @host       = FactoryGirl.create(:host)

      @worker = FactoryGirl.create(:miq_worker, :miq_server_id => @miq_server.id)
      @schedule_worker_settings = MiqScheduleWorker.worker_settings

      @vm       = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id, :host_id => @host.id)
      @job      = @vm.scan
    end

    context "where job is dispatched but never started" do
      before(:each) do
        @job.update_attribute(:dispatch_status, "active")

        Timecop.travel 5.minutes

        Job.check_jobs_for_timeout
      end

      after(:each) do
        Timecop.return
      end

      context "after queue message is processed" do
        before(:each) do
          @msg = MiqQueue.get(:role => "smartstate", :zone => @zone.name)
          status, message, result = @msg.deliver
          @msg.delivered(status, message, result)

          @job.reload
        end

        it "should queue a timeout job if one not already on there" do
          expect { @job.timeout! }.to change{ MiqQueue.count }.by(1)
        end

        it "should be timed out after 5 minutes" do
          $log.info("@job: #{@job.inspect}")
          @job.state.should  == "finished"
          @job.status.should == "error"
          @job.message.starts_with?("job timed out after").should be_true
        end
      end

      it "should not queue a timeout job if one is already on there" do
        expect { @job.timeout! }.not_to change{ MiqQueue.count }.by(1)
      end

      it "should queue a timeout job if one is there, but it is failed" do
        MiqQueue.first.update_attributes(state: MiqQueue::STATE_ERROR)
        expect { @job.timeout! }.to change{ MiqQueue.count }.by(1)
      end
    end

    context "where job is for a repository VM (no zone)" do
      before(:each) do
        @job.update_attributes(:state => "scanning", :dispatch_status => "active", :zone => nil)

        Timecop.travel 5.minutes

        Job.check_jobs_for_timeout

        @msg = MiqQueue.get(:role => "smartstate", :zone => @zone.name)
        status, message, result = @msg.deliver
        @msg.delivered(status, message, result)

        @job.reload
      end

      after(:each) do
        Timecop.return
      end

      it "should be timed out after 5 minutes" do
        $log.info("@job: #{@job.inspect}")
        @job.state.should  == "finished"
        @job.status.should == "error"
        @job.message.starts_with?("job timed out after").should be_true
      end
    end

    context "where 2 VMs in 2 Zones have an EVM Snapshot" do
      before(:each) do
        scan_type   = nil
        build       = '12345'
        description = "Snapshot for scan job: #{@job.guid}, EVM Server build: #{build} #{scan_type} Server Time: #{Time.now.utc.iso8601}"
        @snapshot = FactoryGirl.create(:snapshot, :vm_or_template_id => @vm.id, :name => 'EvmSnapshot', :description => description)

        @zone2     = FactoryGirl.create(:zone, :name => "Zone 2")
        @ems2      = FactoryGirl.create(:ems_vmware, :zone => @zone2, :name => "Test EMS 2")
        @vm2       = FactoryGirl.create(:vm_vmware, :ems_id => @ems2.id)
        @job2      = @vm2.scan
        @job2.zone = @zone2.name
        description = "Snapshot for scan job: #{@job2.guid}, EVM Server build: #{build} #{scan_type} Server Time: #{Time.now.utc.iso8601}"
        @snapshot2 = FactoryGirl.create(:snapshot, :vm_or_template_id => @vm2.id, :name => 'EvmSnapshot', :description => description)
      end

      it "should create proper AR relationships" do
        @snapshot.vm_or_template.should  == @vm
        @vm.snapshots.first.should       == @snapshot
        @vm.ext_management_system.should == @ems
        @ems.vms.first.should            == @vm

        @snapshot2.vm_or_template.should  == @vm2
        @vm2.snapshots.first.should       == @snapshot2
        @vm2.ext_management_system.should == @ems2
        @ems2.vms.first.should            == @vm2
      end

      it "should be able to find Job from Evm Snapshot" do
        job_guid, ts = Snapshot.parse_evm_snapshot_description(@snapshot.description)
        Job.find_by_guid(job_guid).should == @job

        job_guid, ts = Snapshot.parse_evm_snapshot_description(@snapshot2.description)
        Job.find_by_guid(job_guid).should == @job2
      end

      context "where job is not found and the snapshot timestamp is less than an hour old with default job_not_found_delay" do
        before(:each) do
          @job.destroy
          Job.check_for_evm_snapshots
        end

        it "should not create delete snapshot queue message" do
          assert_no_queue_message
        end
      end

      context "where job is not found and the snapshot timestamp is less than an hour old with job_not_found_delay from worker settings" do
        before(:each) do
          @job.destroy
          Job.check_for_evm_snapshots(@schedule_worker_settings[:evm_snapshot_delete_delay_for_job_not_found])
        end

        it "should not create delete snapshot queue message" do
          assert_no_queue_message
        end
      end

      context "where job is not found and the snapshot timestamp is more than an hour old with job_not_found_delay from worker settings" do
        before(:each) do
          @job.destroy
          Timecop.travel 61.minutes
          Job.check_for_evm_snapshots(@schedule_worker_settings[:evm_snapshot_delete_delay_for_job_not_found])
        end

        after(:each) do
          Timecop.return
        end

        it "should create delete snapshot queue message" do
          assert_queue_message
        end
      end

      context "where job is not found and job_not_found_delay passed with 5 minutes and the snapshot timestamp is more than an 5 minutes old" do
        before(:each) do
          @job.destroy
          Timecop.travel 6.minutes
          Job.check_for_evm_snapshots(5.minutes)
        end

        after(:each) do
          Timecop.return
        end

        it "should create delete snapshot queue message" do
          assert_queue_message
        end
      end

      context "where job is not found and the snapshot timestamp is nil" do
        before(:each) do
          @job.destroy
          @snapshot.update_attribute(:description, "Foo")
          Job.check_for_evm_snapshots
        end

        it "should create delete snapshot queue message" do
          assert_queue_message
        end
      end

      context "where job is active" do
        before(:each) do
          @job.update_attribute(:state, "active")
          Job.check_for_evm_snapshots
        end

        it "should not create delete snapshot queue message" do
          assert_no_queue_message
        end
      end

      context "where job is finished" do
        before(:each) do
          @job.update_attribute(:state, "finished")
          Job.check_for_evm_snapshots
        end

        it "should create delete snapshot queue message" do
          assert_queue_message

          Job.check_for_evm_snapshots

          assert_queue_message
        end

        # it "should deliver message without error" do
        #   Host.any_instance.stub(:miq_proxy).and_return(@miq_server)
        #   lambda { MiqQueue.first.deliver }.should_not raise_error
        # end

      end
    end
  end

  private

  def assert_queue_message
    MiqQueue.count.should == 1
    q = MiqQueue.first
    q.instance_id.should == @vm.id
    q.class_name.should  == @vm.class.name
    q.method_name.should == "remove_snapshot"
    q.args.should        == [@snapshot.id]
    q.role.should        == "ems_operations"
    q.zone.should        == @zone.name
  end

  def assert_no_queue_message
    MiqQueue.count.should == 0
  end
end
