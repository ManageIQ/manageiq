describe Job do
  context "With a single scan job," do
    before(:each) do
      @server1 = EvmSpecHelper.local_miq_server(:is_master => true)
      @server2 = FactoryGirl.create(:miq_server, :zone => @server1.zone)

      @miq_server = EvmSpecHelper.local_miq_server(:is_master => true)
      @zone = @miq_server.zone
      @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone, :name => "Test EMS")
      @host       = FactoryGirl.create(:host)

      @worker = FactoryGirl.create(:miq_worker, :miq_server_id => @miq_server.id)
      @schedule_worker_settings = MiqScheduleWorker.worker_settings

      @vm       = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id, :host_id => @host.id)
      @job      = @vm.raw_scan
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
          expect { @job.timeout! }.to change { MiqQueue.count }.by(1)
        end

        it "should be timed out after 5 minutes" do
          $log.info("@job: #{@job.inspect}")
          expect(@job.state).to eq("finished")
          expect(@job.status).to eq("error")
          expect(@job.message.starts_with?("job timed out after")).to be_truthy
        end
      end

      it "should not queue a timeout job if one is already on there" do
        expect { @job.timeout! }.not_to change { MiqQueue.count }
      end

      it "should queue a timeout job if one is there, but it is failed" do
        MiqQueue.first.update_attributes(:state => MiqQueue::STATE_ERROR)
        expect { @job.timeout! }.to change { MiqQueue.count }.by(1)
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
        expect(@job.state).to eq("finished")
        expect(@job.status).to eq("error")
        expect(@job.message.starts_with?("job timed out after")).to be_truthy
      end
    end

    context "where job is for a VM that disappeared" do
      before(:each) do
        @job.update_attributes(:state => "scanning", :dispatch_status => "active", :zone => nil)

        @vm.destroy

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
        expect(@job.state).to eq("finished")
        expect(@job.status).to eq("error")
        expect(@job.message.starts_with?("job timed out after")).to be_truthy
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
        @job2      = @vm2.raw_scan
        @job2.zone = @zone2.name
        description = "Snapshot for scan job: #{@job2.guid}, EVM Server build: #{build} #{scan_type} Server Time: #{Time.now.utc.iso8601}"
        @snapshot2 = FactoryGirl.create(:snapshot, :vm_or_template_id => @vm2.id, :name => 'EvmSnapshot', :description => description)
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
        job_guid, ts = Snapshot.parse_evm_snapshot_description(@snapshot.description)
        expect(Job.find_by_guid(job_guid)).to eq(@job)

        job_guid, ts = Snapshot.parse_evm_snapshot_description(@snapshot2.description)
        expect(Job.find_by_guid(job_guid)).to eq(@job2)
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
      end
    end

    context "where scan jobs exist for both vms and container images" do
      before(:each) do
        @ems_k8s = FactoryGirl.create(
          :ems_kubernetes, :hostname => "test.com", :zone => @zone, :port => 8443,
          :authentications => [AuthToken.new(:name => "test", :type => 'AuthToken', :auth_key => "a secret")]
        )
        @image = FactoryGirl.create(
          :container_image, :ext_management_system => @ems_k8s, :name => 'test',
          :image_ref => "docker://3629a651e6c11d7435937bdf41da11cf87863c03f2587fa788cf5cbfe8a11b9a"
        )
        @image_scan_job = @image.ext_management_system.raw_scan_job_create(@image)
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
      end
    end
  end

  private

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
