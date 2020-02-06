RSpec.describe JobProxyDispatcher do
  include Spec::Support::JobProxyDispatcherHelper

  NUM_VMS = 3
  NUM_REPO_VMS = 3
  NUM_HOSTS = 3
  NUM_SERVERS = 3
  NUM_STORAGES = 3

  let(:zone) { FactoryBot.create(:zone) }
  let(:dispatcher) do
    JobProxyDispatcher.new.tap do |dispatcher|
      dispatcher.instance_variable_set(:@zone, zone.name)
    end
  end

  before do
    @server = EvmSpecHelper.local_miq_server(:name => "test_server_main_server", :zone => zone)
  end

  describe '.waiting?' do
    let(:vm_scan_job) { VmScan.create_job }
    let(:infra_conversion_job) { InfraConversionJob.create_job }

    it 'returns true if VmScan state is waiting to start and InfraConversionJob state is finished' do
      vm_scan_job.update!(:state => 'waiting_to_start')
      infra_conversion_job.update!(:state => 'finished')
      expect(JobProxyDispatcher.waiting?).to be_truthy
    end

    it 'returns true if VmScan state is fake_state and InfraConversionJob state is waiting_to_start' do
      vm_scan_job.update!(:state => 'fake_state')
      infra_conversion_job.update!(:state => 'waiting_to_start')
      expect(JobProxyDispatcher.waiting?).to be_truthy
    end

    it 'returns true if VmScan state is fake_state and InfraConversionJob state is restoring_vm_attributes' do
      vm_scan_job.update!(:state => 'fake_state')
      infra_conversion_job.update!(:state => 'restoring_vm_attributes')
      expect(JobProxyDispatcher.waiting?).to be_truthy
    end

    it 'returns false if VmScan state is fake_state and no InfraConversionJob state is finished' do
      vm_scan_job.update!(:state => 'fake_state')
      infra_conversion_job.update!(:state => 'restoring_vm_attributes')
      expect(JobProxyDispatcher.waiting?).to be_truthy
    end
  end

  context "With a default zone, server, with hosts with a miq_proxy, vmware vms on storages" do
    before do
      (NUM_SERVERS - 1).times do |i|
        FactoryBot.create(:miq_server, :zone => @server.zone, :name => "test_server_#{i}")
      end

      # TODO: We should be able to set values so we don't need to stub behavior
      allow_any_instance_of(MiqServer).to receive_messages(:is_vix_disk? => true)
      allow_any_instance_of(MiqServer).to receive_messages(:is_a_proxy? => true)
      allow_any_instance_of(MiqServer).to receive_messages(:has_active_role? => true)
      allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:missing_credentials? => false)
      allow_any_instance_of(Host).to receive_messages(:missing_credentials? => false)

      @hosts, @proxies, @storages, @vms, @repo_vms, @container_providers = build_entities(
        :hosts => NUM_HOSTS, :storages => NUM_STORAGES, :vms => NUM_VMS, :repo_vms => NUM_REPO_VMS, :zone => zone
      )
      @container_images = @container_providers.collect(&:container_images).flatten
    end

    describe "#dispatch" do
      it "should have a server in default zone" do
        expect(@server.zone).not_to be_nil
        expect(@server).not_to be_nil
      end

      it "should have #{NUM_HOSTS} hosts" do
        expect(NUM_HOSTS).to eq(@hosts.length)
      end

      it "should have #{NUM_VMS} vms and #{NUM_REPO_VMS} repo vms" do
        expect(NUM_VMS).to eq(@vms.length)
      end

      it "should have #{NUM_REPO_VMS} repo vms" do
        expect(NUM_REPO_VMS).to eq(@repo_vms.length)
      end

      context "with a vm without a storage" do
        before do
          # Test a vm without a storage (ie, removed from VC but retained in the VMDB)
          @vm = @vms.first
          @vm.storage = nil
          @vm.save
          @vm.raw_scan
        end

        it "should expect queue_signal and dispatch without errors" do
          expect(dispatcher).to receive(:queue_signal)
          expect { dispatcher.dispatch }.not_to raise_error
        end
      end

      context "with a Microsoft vm without a storage" do
        before do
          # Test a Microsoft vm without a storage
          @vm = @vms.first
          @vm.storage = nil
          @vm.vendor = "microsoft"
          @vm.save
          @vm.raw_scan
        end

        it "should run dispatch without calling queue_signal" do
          expect(dispatcher).not_to receive(:queue_signal)
        end
      end

      context "with a Microsoft vm with a Microsoft storage" do
        before do
          # Test a Microsoft vm without a storage
          @vm = @vms.first
          @vm.storage.store_type = "CSVFS"
          @vm.vendor = "microsoft"
          @vm.save
          @vm.raw_scan
        end

        it "should run dispatch without calling queue_signal" do
          expect(dispatcher).not_to receive(:queue_signal)
        end
      end

      context "with a Microsoft vm with an invalid storage" do
        before do
          # Test a Microsoft vm without a storage
          @vm = @vms.first
          @vm.storage.store_type = "XFS"
          @vm.vendor = "microsoft"
          @vm.save
          @vm.raw_scan
        end

        it "should expect queue_signal and dispatch without errors" do
          expect(dispatcher).to receive(:queue_signal)
          expect { dispatcher.dispatch }.not_to raise_error
        end
      end

      context "with jobs, a default smartproxy for repo scanning" do
        before do
          @repo_proxy = @proxies.last
          if @repo_proxy
            @repo_proxy.name = "repo_proxy"
            @repo_proxy.save
            @repo_proxy.host.name = "repo_host"
            @repo_proxy.host.save
            stub_settings(:repository_scanning => {:defaultsmartproxy => @repo_proxy.id})
          end
          @jobs = (@vms + @repo_vms).collect(&:raw_scan)
        end

        # Don't run these tests if we only want to run dispatch for load testing
        if @repo_proxy
          it "should have repository host set" do
            expect(@repo_vms.first.myhost.id).to eq(@repo_proxy.host_id)
          end
        end

        it "should have #{NUM_VMS + NUM_REPO_VMS} jobs" do
          total = NUM_VMS + NUM_REPO_VMS
          expect(@jobs.length).to eq(total)
        end

        it "should run dispatch" do
          expect { JobProxyDispatcher.dispatch }.not_to raise_error
        end

        it "dispatch should handle a job with a deleted target VM" do
          @job = Job.first
          @job.target_id = 999999
          @job.save!
          expect { JobProxyDispatcher.dispatch }.not_to raise_error
          @job.reload
          expect(@job.state).to eq("finished")
          expect(@job.status).to eq("warn")
        end
      end
    end

    context "with container and vms jobs" do
      let (:container_image_classes) { ContainerImage.descendants.collect(&:name).append('ContainerImage') }
      before do
        @jobs = (@vms + @repo_vms).collect(&:raw_scan)
        User.current_user = FactoryBot.create(:user)
        @jobs += @container_images.map { |img| img.ext_management_system.raw_scan_job_create(img.class, img.id) }
      end

      describe "#pending_jobs" do
        it "returns only vm jobs by default" do
          jobs = dispatcher.pending_jobs
          expect(jobs.count).to eq(@vms.count + @repo_vms.count)
          jobs.each do |x|
            expect(x.target_class).to eq 'VmOrTemplate'
          end
          expect(jobs.count).to be > 0 # in case something unexpected goes wrong
        end

        it "returns only container images jobs when requested" do
          jobs = dispatcher.pending_jobs(dispatcher.container_image_scan_class)
          expect(jobs.count).to eq(@container_images.count)
          jobs.each do |x|
            expect(container_image_classes).to include x.target_class
          end
          expect(jobs.count).to be > 0 # in case something unexpected goes wrong
        end
      end

      describe "#pending_container_jobs" do
        it "returns container jobs by provider" do
          jobs_by_ems, = dispatcher.pending_container_jobs
          expect(jobs_by_ems.keys).to match_array(@container_providers.map(&:id))

          expect(jobs_by_ems[@container_providers.first.id].count).to eq(1 * container_image_classes.count)
          expect(jobs_by_ems[@container_providers.second.id].count).to eq(2 * container_image_classes.count)
        end
      end

      describe "#active_container_scans_by_zone_and_ems" do
        it "returns active container acans for zone" do
          job = @jobs.find { |j| container_image_classes.include?(j.target_class) }
          job.update(:dispatch_status => "active")
          provider = ExtManagementSystem.find(job.options[:ems_id])
          expect(dispatcher.active_container_scans_by_zone_and_ems).to eq(
            job.zone => {provider.id => 1}
          )
        end
      end

      describe "#dispatch_container_scan_jobs" do
        it "dispatches jobs until reaching limit" do
          stub_settings(:container_scanning => {:concurrent_per_ems => 1})
          dispatcher.dispatch_container_scan_jobs
          expect(Job.where(:target_class => container_image_classes, :dispatch_status => "pending").count).to eq(
            (3 * container_image_classes.count) - 2)
          # 1 per ems, one ems has 1* job and the other 2*
          # initial number of images per ems is multiplied by container_image_classes.count
        end

        it "does not dispach if limit is already reached" do
          stub_settings(:container_scanning => {:concurrent_per_ems => 1})
          dispatcher.dispatch_container_scan_jobs
          expect(Job.where(:target_class => container_image_classes, :dispatch_status => "pending").count).to eq(
            (3 * container_image_classes.count) - 2)
          dispatcher.dispatch_container_scan_jobs
          expect(Job.where(:target_class => container_image_classes, :dispatch_status => "pending").count).to eq(
            (3 * container_image_classes.count) - 2)
        end

        it "does not apply limit when concurrent_per_ems is 0" do
          stub_settings(:container_scanning => {:concurrent_per_ems => 0})
          dispatcher.dispatch_container_scan_jobs
          expect(Job.where(:target_class => container_image_classes, :dispatch_status => "pending").count).to eq(0)
          # 1 per ems, one ems has 1* job and the other 2*
          # initial number of images per ems is multiplied by container_image_classes.count
        end

        it "does not apply limit when concurrent_per_ems is -1" do
          stub_settings(:container_scanning => {:concurrent_per_ems => -1})
          dispatcher.dispatch_container_scan_jobs
          expect(Job.where(:target_class => container_image_classes, :dispatch_status => "pending").count).to eq(0)
          # 1 per ems, one ems has 1* job and the other 2*
          # initial number of images per ems is multiplied by container_image_classes.count
        end
      end
    end

    describe "#active_vm_scans_by_zone" do
      it "returns active vm scans for this zone" do
        job = @vms.first.raw_scan
        job.update(:dispatch_status => "active")
        expect(dispatcher.active_vm_scans_by_zone[job.zone]).to eq(1)
      end

      it "returns 0 for active vm scan for other zones" do
        job = @vms.first.raw_scan
        job.update(:dispatch_status => "active")
        expect(dispatcher.active_vm_scans_by_zone['defult']).to eq(0)
      end
    end
  end

  context "limiting number of smart state analysis running on one server" do
    let(:job) { VmScan.create_job(:miq_server_id => @server.id, :name => "Hello - 1") }
    before do
      VmScan.create_job(:miq_server_id => @server.id, :name => "Hello - 2")
            .update(:dispatch_status => "active")
      VmScan.create_job(:miq_server_id => @server.id, :name => "Hello - 3")
            .update(:dispatch_status => "active")
    end

    describe "#busy_proxies" do
      it "it returns hash with number of not finished jobs with dispatch status 'active' for each MiqServer" do
        expect(dispatcher.busy_proxies).to eq "MiqServer_#{@server.id}" => 2
      end
    end

    describe "#assign_proxy_to_job" do
      it "increses by 1 number of jobs (how busy server is) for server" do
        expect(dispatcher.busy_proxies).to eq "MiqServer_#{@server.id}" => 2
        allow(dispatcher).to receive(:embedded_scan_resource).and_return(nil)
        dispatcher.assign_proxy_to_job(@server, job)
        expect(dispatcher.busy_proxies).to eq "MiqServer_#{@server.id}" => 3
      end

      it "links job to instance of MiqServer and updates :started_on and :dispatch_status atributes" do
        allow(dispatcher).to receive(:embedded_scan_resource).and_return(nil)
        Timecop.freeze do
          timestamp = Time.now.utc
          dispatcher.assign_proxy_to_job(@server, job)
          expect(job.started_on).to eq timestamp
        end
        expect(job.miq_server_id).to eq @server.id
        expect(job.dispatch_status).to eq "active"
      end
    end
  end

  describe "#start_job_on_proxy" do
    it "creates job options and passing it to `queue_signal'" do
      job = VmScan.create_job(:miq_server_id => @server.id, :name => "Hello, World")
      dispatcher.instance_variable_set(:@active_vm_scans_by_zone, @server.my_zone => 0)

      job_options = {:args => ["start"], :zone => @server.my_zone, :server_guid => @server.guid, :role => "smartproxy"}
      expect(dispatcher).to receive(:assign_proxy_to_job)
      expect(dispatcher).to receive(:queue_signal).with(job, job_options)

      dispatcher.start_job_on_proxy(job, @server)
    end
  end

  describe "#do_dispatch" do
    let(:ems_id) { 1 }
    let(:job) { VmScan.create_job(:name => "Hello, World") }

    before do
      dispatcher.instance_variable_set(:@active_container_scans_by_zone_and_ems, @server.my_zone => {ems_id => 0})
    end

    it "updates 'dispatch_status' attribute of job record to 'active'" do
      expect(job.dispatch_status).not_to eq "active"
      dispatcher.do_dispatch(job, ems_id)
      expect(job.dispatch_status).to eq "active"
    end

    it "updates ':started_on' attribute of job record" do
      expect(job.started_on).to be nil
      Timecop.freeze do
        timestamp = Time.now.utc
        dispatcher.do_dispatch(job, ems_id)
        expect(job.started_on).to eq timestamp
      end
    end

    it "increases counter of active container scans by zone and ems by 1" do
      counter_by_zone_ems = dispatcher.instance_variable_get(:@active_container_scans_by_zone_and_ems)
      expect(counter_by_zone_ems[@server.my_zone][ems_id]).to eq 0

      dispatcher.do_dispatch(job, ems_id)

      counter_by_zone_ems = dispatcher.instance_variable_get(:@active_container_scans_by_zone_and_ems)
      expect(counter_by_zone_ems[@server.my_zone][ems_id]).to eq 1
    end

    it "queues call to Job::StateMachine#signal with argument 'start'" do
      expect(MiqQueue.count).to eq 0

      dispatcher.do_dispatch(job, ems_id)

      queue_record = MiqQueue.where(:instance_id => job.id)[0]
      expect(queue_record.method_name).to eq "signal"
      expect(queue_record.class_name).to eq "Job"
    end
  end

  describe "#queue_signal" do
    let(:job) { VmScan.create_job(:name => "Hello, World") }

    it "queues call to Job::StateMachine#signal_abort if signal is 'abort'" do
      options = {:args => [:abort]}

      dispatcher.queue_signal(job, options)

      queue_record = MiqQueue.where(:instance_id => job.id)[0]
      expect(queue_record.method_name).to eq "signal_abort"
      expect(queue_record.class_name).to eq "Job"
    end

    it "queues call to Job::StateMachine#signal if signal is not 'abort'" do
      options = {:args => [:start_snapshot]}

      dispatcher.queue_signal(job, options)

      queue_record = MiqQueue.where(:instance_id => job.id)[0]
      expect(queue_record.method_name).to eq "signal"
      expect(queue_record.class_name).to eq "Job"
      expect(queue_record.args[0]).to eq :start_snapshot
    end
  end

  describe "#dispatch_to_ems" do
    let(:ems_id) { 1 }
    let(:jobs) do
      [VmScan.create_job(:name => "Hello, World 1"), VmScan.create_job(:name => "Hello, World 2")]
    end

    it "dispatches all supplied jobs if supplied concurency limit is 0" do
      dispatcher.dispatch_to_ems(ems_id, jobs, 0)
      expect(MiqQueue.where(:class_name => "Job", :method_name => "signal").count).to eq 2
    end

    it "limits dispatching supplied jobs if supplied concurrency limit > 0" do
      concurrency_limit = 1
      dispatcher.dispatch_to_ems(ems_id, jobs, concurrency_limit)
      expect(MiqQueue.where(:class_name => "Job", :method_name => "signal").count).to eq concurrency_limit
    end
  end
end
