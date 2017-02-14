describe MiqWorker do
  context "::Runner" do
    def all_workers
      MiqWorker.descendants.select { |c| c.subclasses.empty? }
    end

    it "finds the correct corresponding runner for workers" do
      all_workers.each do |worker|
        # If this isn't true, we're probably accidentally inheriting the
        # runner from a superclass
        expect(worker::Runner.name).to eq("#{worker.name}::Runner")
      end
    end
  end

  context ".sync_workers" do
    it "stops extra workers, returning deleted pids" do
      expect_any_instance_of(described_class).to receive(:stop)
      worker = FactoryGirl.create(:miq_worker, :status => "started")
      worker.class.workers = 0
      expect(worker.class.sync_workers).to eq(:adds => [], :deletes => [worker.pid])
    end
  end

  it "renice" do
    allow(AwesomeSpawn).to receive(:launch)
    allow(described_class).to receive(:worker_settings).and_return(:nice_delta => 5)
    result = described_class.renice(123)
    expect(result.command_line).to eq "renice -n 5 -p 123"
  end

  context ".has_required_role?" do
    def check_has_required_role(worker_role_names, expected_result)
      allow(described_class).to receive(:required_roles).and_return(worker_role_names)
      expect(described_class.has_required_role?).to eq(expected_result)
    end

    before(:each) do
      active_roles = %w(foo bar).map { |rn| FactoryGirl.create(:server_role, :name => rn) }
      @server = EvmSpecHelper.local_miq_server(:active_roles => active_roles)
    end

    context "clean_active_messages" do
      before do
        @worker = FactoryGirl.create(:miq_worker, :miq_server => @server)
        @message = FactoryGirl.create(:miq_queue, :handler => @worker, :state => 'dequeue')
      end

      it "normal" do
        expect(@worker.active_messages.length).to eq(1)
        @worker.clean_active_messages
        expect(@worker.reload.active_messages.length).to eq(0)
      end

      it "invokes a message callback" do
        @message.update_attribute(:miq_callback, :class_name => 'Kernel', :method_name => 'rand')
        expect(Kernel).to receive(:rand)
        @worker.clean_active_messages
      end
    end

    it "when worker roles is nil" do
      check_has_required_role(nil, true)
    end

    context "when worker roles is a string" do
      it "that is blank" do
        check_has_required_role(" ", true)
      end

      it "that is one of the server roles" do
        check_has_required_role("foo", true)
      end

      it "that is not one of the server roles" do
        check_has_required_role("baa", false)
      end
    end

    context "when worker roles is an array" do
      it "that is empty" do
        check_has_required_role([], true)
      end

      it "that is a subset of server roles" do
        check_has_required_role(["foo"], true)
        check_has_required_role(%w(bah foo), true)
      end

      it "that is not a subset of server roles" do
        check_has_required_role(["bah"], false)
      end
    end
  end

  context ".workers_configured_count" do
    before(:each) do
      @configured_count = 2
      allow(described_class).to receive(:worker_settings).and_return(:count => @configured_count)
      @maximum_workers_count = described_class.maximum_workers_count
    end

    after(:each) do
      described_class.maximum_workers_count = @maximum_workers_count
    end

    it "when maximum_workers_count is nil" do
      expect(described_class.workers_configured_count).to eq(@configured_count)
    end

    it "when maximum_workers_count is less than configured_count" do
      described_class.maximum_workers_count = 1
      expect(described_class.workers_configured_count).to eq(1)
    end

    it "when maximum_workers_count is equal to the configured_count" do
      described_class.maximum_workers_count = 2
      expect(described_class.workers_configured_count).to eq(@configured_count)
    end

    it "when maximum_workers_count is greater than configured_count" do
      described_class.maximum_workers_count = 2
      expect(described_class.workers_configured_count).to eq(@configured_count)
    end
  end

  describe ".worker_settings" do
    let(:settings) do
      {
        :workers => {
          :worker_base => {
            :defaults          => {:memory_threshold => "100.megabytes"},
            :queue_worker_base => {
              :defaults           => {:memory_threshold => "300.megabytes"},
              :ems_refresh_worker => {
                :defaults                  => {:memory_threshold => "500.megabytes"},
                :ems_refresh_worker_amazon => {
                  :memory_threshold => "700.megabytes"
                }
              }
            }
          }
        }
      }
    end

    before do
      EvmSpecHelper.create_guid_miq_server_zone
      stub_settings(settings)
    end

    context "at a concrete subclass" do
      let(:actual) { ManageIQ::Providers::Amazon::CloudManager::RefreshWorker.worker_settings[:memory_threshold] }

      it "with overrides" do
        expect(actual).to eq(700.megabytes)
      end

      it "without overrides" do
        settings.store_path(:workers, :worker_base, :queue_worker_base, :ems_refresh_worker, :ems_refresh_worker_amazon, {})
        stub_settings(settings)

        expect(actual).to eq(500.megabytes)
      end
    end

    context "at the BaseManager level" do
      let(:actual) { ManageIQ::Providers::BaseManager::RefreshWorker.worker_settings[:memory_threshold] }
      it "with overrides" do
        expect(actual).to eq(500.megabytes)
      end

      it "without overrides" do
        settings.store_path(:workers, :worker_base, :queue_worker_base, :ems_refresh_worker, :defaults, {})
        stub_settings(settings)

        expect(actual).to eq(300.megabytes)
      end
    end

    context "at the MiqQueueWorkerBase level" do
      let(:actual) { MiqQueueWorkerBase.worker_settings[:memory_threshold] }
      it "with overrides" do
        expect(actual).to eq(300.megabytes)
      end

      it "without overrides" do
        settings.store_path(:workers, :worker_base, :queue_worker_base, :defaults, {})
        stub_settings(settings)

        expect(actual).to eq(100.megabytes)
      end
    end

    it "at the base class" do
      actual = MiqWorker.worker_settings[:memory_threshold]
      expect(actual).to eq(100.megabytes)
    end

    it "uses passed in config" do
      settings.store_path(:workers, :worker_base, :queue_worker_base, :ems_refresh_worker, :ems_refresh_worker_amazon, :memory_threshold, "1.terabyte")
      stub_settings(settings)

      config = VMDB::Config.new("vmdb")
      actual = ManageIQ::Providers::Amazon::CloudManager::RefreshWorker.worker_settings(:config => config)[:memory_threshold]
      expect(actual).to eq(1.terabyte)
    end
  end

  context "with two servers" do
    before do
      allow(described_class).to receive(:nice_increment).and_return("+10")

      @zone = FactoryGirl.create(:zone)
      @server = FactoryGirl.create(:miq_server, :zone => @zone)
      allow(MiqServer).to receive(:my_server).and_return(@server)
      @worker = FactoryGirl.create(:ems_refresh_worker_amazon, :miq_server => @server)

      @server2 = FactoryGirl.create(:miq_server, :zone => @zone)
      @worker2 = FactoryGirl.create(:ems_refresh_worker_amazon, :miq_server => @server2)
    end

    it ".server_scope" do
      expect(described_class.server_scope).to eq([@worker])
    end

    it ".server_scope with a different server" do
      expect(described_class.server_scope(@server2.id)).to eq([@worker2])
    end

    it ".server_scope after already scoping on a different server" do
      described_class.where(:miq_server_id => @server2.id).scoping do
        expect(described_class.server_scope).to eq([@worker2])
        expect(described_class.server_scope(@server.id)).to eq([@worker2])
      end
    end

    describe "#worker_settings" do
      let(:config1) do
        {
          :workers => {
            :worker_base => {
              :defaults          => {:memory_threshold => "100.megabytes"},
              :queue_worker_base => {
                :defaults           => {:memory_threshold => "300.megabytes"},
                :ems_refresh_worker => {
                  :defaults                  => {:memory_threshold => "500.megabytes"},
                  :ems_refresh_worker_amazon => {
                    :memory_threshold => "700.megabytes"
                  }
                }
              }
            }
          }
        }
      end

      let(:config2) do
        {
          :workers => {
            :worker_base => {
              :defaults          => {:memory_threshold => "200.megabytes"},
              :queue_worker_base => {
                :defaults           => {:memory_threshold => "400.megabytes"},
                :ems_refresh_worker => {
                  :defaults                  => {:memory_threshold => "600.megabytes"},
                  :ems_refresh_worker_amazon => {
                    :memory_threshold => "800.megabytes"
                  }
                }
              }
            }
          }
        }
      end

      before do
        Vmdb::Settings.save!(@server,  config1)
        Vmdb::Settings.save!(@server2, config2)
      end

      it "uses the worker's miq_server" do
        expect(@worker.worker_settings[:memory_threshold]).to  eq(700.megabytes)
        expect(@worker2.worker_settings[:memory_threshold]).to eq(800.megabytes)
      end

      it "uses passed in config" do
        expect(@worker.worker_settings(:config => config2)[:memory_threshold]).to  eq(800.megabytes)
        expect(@worker2.worker_settings(:config => config1)[:memory_threshold]).to eq(700.megabytes)
      end

      it "without overrides" do
        @server.settings_changes.where(
          :key => "/workers/worker_base/queue_worker_base/ems_refresh_worker/ems_refresh_worker_amazon/memory_threshold"
        ).delete_all
        expect(@worker.worker_settings[:memory_threshold]).to  eq(500.megabytes)
        expect(@worker2.worker_settings[:memory_threshold]).to eq(800.megabytes)
      end
    end
  end

  describe ".config_settings_path" do
    let(:capu_worker) do
      ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker
    end

    it "include parent entries" do
      expect(capu_worker.config_settings_path).to eq(
        %i(workers worker_base queue_worker_base ems_metrics_collector_worker ems_metrics_collector_worker_amazon)
      )
    end

    it "works for high level entries" do
      expect(MiqEmsMetricsCollectorWorker.config_settings_path).to eq(
        %i(workers worker_base queue_worker_base ems_metrics_collector_worker)
      )
    end
  end

  context "instance" do
    before(:each) do
      allow(described_class).to receive(:nice_increment).and_return("+10")
      @worker = FactoryGirl.create(:miq_worker)
    end

    it "#worker_options" do
      expect(@worker.worker_options).to eq(:guid => @worker.guid)
    end

    describe "#stopping_for_too_long?" do
      subject { @worker.stopping_for_too_long? }

      it "false if started" do
        @worker.update(:status => described_class::STATUS_STARTED)
        expect(subject).to be_falsey
      end

      it "true if stopping and not heartbeated recently" do
        @worker.update(:status         => described_class::STATUS_STOPPING,
                       :last_heartbeat => 30.minutes.ago)
        expect(subject).to be_truthy
      end

      it "false if stopping and heartbeated recently" do
        @worker.update(:status         => described_class::STATUS_STOPPING,
                       :last_heartbeat => 1.minute.ago)
        expect(subject).to be_falsey
      end
    end

    it "is_current? false when starting" do
      @worker.update_attribute(:status, described_class::STATUS_STARTING)
      expect(@worker.is_current?).not_to be_truthy
    end

    it "is_current? true when started" do
      @worker.update_attribute(:status, described_class::STATUS_STARTED)
      expect(@worker.is_current?).to be_truthy
    end

    it "is_current? true when working" do
      @worker.update_attribute(:status, described_class::STATUS_WORKING)
      expect(@worker.is_current?).to be_truthy
    end

    context ".status_update" do
      before do
        @worker.update_attribute(:pid, 123)
        require 'miq-process'
      end

      it "no such process" do
        allow(MiqProcess).to receive(:processInfo).with(123).and_raise(Errno::ESRCH)
        described_class.status_update
        @worker.reload
        expect(@worker.status).to eq MiqWorker::STATUS_ABORTED
      end

      it "a StandardError" do
        allow(MiqProcess).to receive(:processInfo).with(123).and_raise(StandardError.new("LOLRUBY"))
        expect($log).to receive(:warn).with(/LOLRUBY/)
        described_class.status_update
      end

      it "updates expected values" do
        values = {
          :pid                   => 123,
          :memory_usage          => 246_824_960,
          :memory_size           => 2_792_611_840,
          :percent_memory        => "1.4",
          :percent_cpu           => "1.0",
          :cpu_time              => 660,
          :priority              => "31",
          :name                  => "ruby",
          :proportional_set_size => 198_721_987
        }

        fields = described_class::PROCESS_INFO_FIELDS.dup

        # convert priority -> os_priority column
        fields.delete(:priority)
        fields << :os_priority

        fields.each do |field|
          expect(@worker.public_send(field)).to be_nil
        end

        allow(MiqProcess).to receive(:processInfo).with(123).and_return(values)
        described_class.status_update
        @worker.reload

        fields.each do |field|
          expect(@worker.public_send(field)).to be_present
        end
        expect(@worker.proportional_set_size).to eq 198_721_987
      end
    end
  end
end
