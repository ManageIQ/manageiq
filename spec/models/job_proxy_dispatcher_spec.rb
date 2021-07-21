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
