RSpec.describe Host do
  subject { FactoryBot.create(:host) }

  include_examples "AggregationMixin"
  include_examples "MiqPolicyMixin"

  it "groups and users joins" do
    user1  = FactoryBot.create(:account_user)
    user2  = FactoryBot.create(:account_user)
    group  = FactoryBot.create(:account_group)
    host1  = FactoryBot.create(:host_vmware, :users => [user1], :groups => [group])
    host2  = FactoryBot.create(:host_vmware, :users => [user2])
    expect(described_class.joins(:users)).to match_array([host1, host2])
    expect(described_class.joins(:groups)).to eq [host1]
    expect(described_class.joins(:users, :groups)).to eq [host1]
  end

  it "directories and files joins" do
    file1  = FactoryBot.create(:filesystem, :rsc_type => "file")
    file2  = FactoryBot.create(:filesystem, :rsc_type => "file")
    dir    = FactoryBot.create(:filesystem, :rsc_type => "dir")
    host1  = FactoryBot.create(:host_vmware, :files => [file1], :directories => [dir])
    host2  = FactoryBot.create(:host_vmware, :files => [file2])
    expect(described_class.joins(:files)).to match_array([host1, host2])
    expect(described_class.joins(:directories)).to eq [host1]
    expect(described_class.joins(:files, :directories)).to eq [host1]
  end

  it "#ems_custom_attributes" do
    ems_attr   = FactoryBot.create(:custom_attribute, :source => 'VC')
    other_attr = FactoryBot.create(:custom_attribute, :source => 'NOTVC')
    host       = FactoryBot.create(:host_vmware, :custom_attributes => [ems_attr, other_attr])
    expect(host.ems_custom_attributes).to eq [ems_attr]
  end

  it "#save_drift_state" do
    # TODO: Beef up with more data
    host = FactoryBot.create(:host_vmware)
    host.save_drift_state

    expect(host.drift_states.size).to eq(1)
    expect(DriftState.count).to eq(1)

    expect(host.drift_states.first.data).to eq({
      :class                         => "ManageIQ::Providers::Vmware::InfraManager::Host",
      :id                            => host.id,
      :name                          => host.name,
      :vmm_vendor_display            => "VMware",
      :v_total_vms                   => 0,

      :advanced_settings             => [],
      :filesystems                   => [],
      :filesystems_custom_attributes => [],
      :groups                        => [],
      :guest_applications            => [],
      :lans                          => [],
      :patches                       => [],
      :switches                      => [],
      :system_services               => [],
      :tags                          => [],
      :users                         => [],
      :vms                           => [],
    })
  end

  it "emits cluster policy event when the cluster changes" do
    # New host added to a cluster
    cluster1 = FactoryBot.create(:ems_cluster)
    host = FactoryBot.build(:host_vmware, :ems_cluster => cluster1)
    expect(MiqEvent).to receive(:raise_evm_event).with(host, "host_add_to_cluster", anything)
    host.save

    # Existing host changes clusters
    cluster2 = FactoryBot.create(:ems_cluster)
    host.ems_cluster = cluster2
    expect(MiqEvent).to receive(:raise_evm_event).with(host, "host_remove_from_cluster", hash_including(:ems_cluster => cluster1))
    expect(MiqEvent).to receive(:raise_evm_event).with(host, "host_add_to_cluster", hash_including(:ems_cluster => cluster2))
    host.save

    # Existing host becomes cluster-less
    host.ems_cluster = nil
    expect(MiqEvent).to receive(:raise_evm_event).with(host, "host_remove_from_cluster", hash_including(:ems_cluster => cluster2))
    host.save
  end

  context "#scannable_status" do
    let(:host) { FactoryBot.build(:host_vmware) }
    subject    { host.scannable_status }
    before do
      allow_any_instance_of(Authentication).to receive(:after_authentication_changed)
      allow(host).to receive(:refreshable_status).and_return(:show => false, :enabled => false)
    end

    it "refreshable_status already reporting error" do
      reportable_status = {:show => true, :enabled => false, :message => "Proxy not active"}
      allow(host).to receive(:refreshable_status).and_return(reportable_status)
      expect(subject).to eq(reportable_status)
    end

    it "ipmi address and creds" do
      host.update_attribute(:ipmi_address, "127.0.0.1")
      host.update_authentication(:ipmi => {:userid => "a", :password => "a"})
      expect(subject).to eq(:show => true, :enabled => true, :message => "")
    end

    it "ipmi address but no creds" do
      host.update_attribute(:ipmi_address, "127.0.0.1")
      expect(subject).to eq(:show => true, :enabled => false, :message => "Provide credentials for IPMI")
    end

    it "creds but no ipmi address" do
      host.update_authentication(:ipmi => {:userid => "a", :password => "a"})
      expect(subject).to eq(:show => true, :enabled => false, :message => "Provide an IPMI Address")
    end

    it "no creds or ipmi address" do
      expect(subject).to eq(:show => true, :enabled => false, :message => "Provide an IPMI Address")
    end
  end

  context "power operations" do
    let(:validation_response) { {:available => false, :message => "The Host is not VMware ESX"} }

    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryBot.create(:ext_management_system, :tenant => FactoryBot.create(:tenant))
      @host = FactoryBot.create(:host, :ems_id => @ems.id)
    end

    context "#start" do
      before do
        allow_any_instance_of(described_class).to receive_messages(:validate_start   => {})
        allow_any_instance_of(described_class).to receive_messages(:validate_ipmi    => {:available => true, :message => nil})
        allow_any_instance_of(described_class).to receive_messages(:run_ipmi_command => "off")
        FactoryBot.create(:miq_event_definition, :name => :request_host_start)
        # admin user is needed to process Events
        FactoryBot.create(:user_with_group, :userid => "admin", :name => "Administrator")
      end

      it "policy passes" do
        expect_any_instance_of(described_class).to receive(:ipmi_power_on)

        MiqQueue.delete_all
        @host.start
        status, message, result = MiqQueue.first.deliver
        MiqQueue.first.delivered(status, message, result)
      end

      it "policy prevented" do
        expect_any_instance_of(described_class).not_to receive(:ipmi_power_on)

        event = {:attributes => {"full_data" => {:policy => {:pprevented => true}}}}
        allow_any_instance_of(MiqAeEngine::MiqAeWorkspaceRuntime).to receive(:get_obj_from_path).with("/").and_return(:event_stream => event)
        @host.start
        status, message, _result = MiqQueue.first.deliver
        MiqQueue.first.delivered(status, message, MiqAeEngine::MiqAeWorkspaceRuntime.new)
      end
    end

    context "with shutdown invalid" do
      it("#shutdown")          { expect { @host.shutdown }.not_to raise_error }
      it("#validate_shutdown") { expect(@host.validate_shutdown).to eq(validation_response) }
    end

    context "with reboot invalid" do
      it("#reboot")          { expect { @host.reboot }.not_to raise_error }
      it("#validate_reboot") { expect(@host.validate_reboot).to eq(validation_response) }
    end

    context "with standby invalid" do
      it("#standby")          { expect { @host.standby }.not_to raise_error }
      it("#validate_standby") { expect(@host.validate_standby).to eq(validation_response) }
    end

    context "with enter_maint_mode invalid" do
      it("#enter_maint_mode")          { expect { @host.enter_maint_mode }.not_to raise_error }
      it("#validate_enter_maint_mode") { expect(@host.validate_enter_maint_mode).to eq(validation_response) }
    end

    context "with exit_maint_mode invalid" do
      it("#exit_maint_mode")          { expect { @host.exit_maint_mode }.not_to raise_error }
      it("#validate_exit_maint_mode") { expect(@host.validate_exit_maint_mode).to eq(validation_response) }
    end
  end

  context "quick statistics retrieval" do
    subject { FactoryBot.build(:host) }

    it("#current_memory_usage") { expect(subject.current_memory_usage).to be_kind_of(Integer) }
    it("#current_cpu_usage")    { expect(subject.current_cpu_usage).to    be_kind_of(Integer) }
  end

  context "#vmm_vendor_display" do
    it("known vendor") { expect(FactoryBot.build(:host_vmware_esx).vmm_vendor_display).to          eq("VMware") }
    it("nil vendor")   { expect(FactoryBot.build(:host, :vmm_vendor => nil).vmm_vendor_display).to eq("Unknown") }
  end

  context "host validation" do
    before do
      EvmSpecHelper.local_miq_server

      @password = "v2:{/OViaBJ0Ug+RSW9n7EFGqw==}"
      @ems = FactoryBot.create(:ems_vmware)
      @host = FactoryBot.create(:host_vmware_esx, :ext_management_system => @ems)
      @data = {:default => {:userid => "root", :password => @password}}
      @options = {:save => false}
    end

    context "#verify_credentials_task" do
      it "verifies the credentials" do
        @host.update_authentication(@data, @options)
        @host.save
        @host.verify_credentials_task(FactoryBot.create(:user).userid)

        expect(MiqQueue.last).to have_attributes(
          :method_name => "verify_credentials?",
          :instance_id => @host.id,
          :class_name  => @host.class.name,
          :role        => "ems_operations",
          :zone        => @ems.zone.name,
          :queue_name  => @ems.queue_name_for_ems_operations,
        )
      end
    end

    context "default credentials" do
      it "save" do
        @host.update_authentication(@data, @options)
        @host.save
        expect(@host.authentications.count).to eq(1)
      end

      it "validate" do
        allow(@host).to receive(:connect_ssh)
        assert_default_credentials_validated
        expect(@host.authentications.count).to eq(0)
      end
    end

    context "default and remote credentials" do
      it "save default, then save remote" do
        @host.update_authentication(@data, @options)
        @host.save
        expect(@host.authentications.count).to eq(1)

        @data[:remote] = {:userid => "root", :password => @password}
        @host.update_authentication(@data, @options)
        @host.save
        expect(@host.authentications.count).to eq(2)
      end

      it "save both together" do
        @data[:remote] = {:userid => "root", :password => @password}
        @host.update_authentication(@data, @options)
        @host.save
        expect(@host.authentications.count).to eq(2)
      end

      it "validate remote with both credentials" do
        @data[:remote] = {:userid => "root", :password => @password}
        assert_remote_credentials_validated
      end

      it "validate default with both credentials" do
        @data[:remote] = {:userid => "root", :password => @password}
        assert_default_credentials_validated
      end

      it "validate default, then validate remote" do
        allow(@host).to receive(:connect_ssh)
        assert_default_credentials_validated

        @data[:remote] = {:userid => "root", :password => @password}
        assert_remote_credentials_validated
      end

      it "validate remote, then validate default" do
        @data = {:default => {:userid => "", :password => ""},
                 :remote  => {:userid => "root", :password => @password},
        }
        assert_remote_credentials_validated

        @data[:default] = {:userid => "root", :password => @password}
        assert_default_credentials_validated
      end
    end
  end

  context "#get_ports" do
    let(:os) { FactoryBot.create(:operating_system) }
    subject  { FactoryBot.create(:host, :operating_system => os) }

    before do
      FactoryBot.create(:firewall_rule, :host_protocol => 'udp', :direction => "in", :enabled => true, :port => 1001, :resource => os)
      FactoryBot.create(:firewall_rule, :host_protocol => 'udp', :direction => "out", :enabled => true, :port => 1002, :resource => os)
      FactoryBot.create(:firewall_rule, :host_protocol => 'tcp', :direction => "in", :enabled => true, :port => 1003, :resource => os)
    end

    it("#enabled_udp_outbound_ports") { expect(subject.enabled_udp_outbound_ports).to match_array([1002]) }
    it("#enabled_inbound_ports")      { expect(subject.enabled_inbound_ports).to      match_array([1003, 1001]) }
  end


  def assert_default_credentials_validated
    allow(@host).to receive(:verify_credentials_with_ws)
    @host.update_authentication(@data, @options)
    expect(@host.verify_credentials(:default)).to be_truthy
  end

  def assert_remote_credentials_validated
    allow(@host).to receive(:connect_ssh)
    @host.update_authentication(@data, @options)
    expect(@host.verify_credentials(:remote)).to be_truthy
  end

  context "#tenant_identity" do
    let(:admin)    { FactoryBot.create(:user_with_group, :userid => "admin") }
    let(:tenant)   { FactoryBot.create(:tenant) }
    let(:ems)      { FactoryBot.create(:ext_management_system, :tenant => tenant) }
    before         { admin }

    subject        { @host.tenant_identity }

    it "has tenant from provider" do
      @host = FactoryBot.create(:host, :ext_management_system => ems)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(ems.tenant.default_miq_group)
      expect(subject.current_tenant).to eq(ems.tenant)
    end

    it "without a provider, has tenant from root tenant" do
      @host = FactoryBot.create(:host)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(Tenant.root_tenant.default_miq_group)
      expect(subject.current_tenant).to eq(Tenant.root_tenant)
    end
  end

  describe "#disconnect_ems" do
    let(:ems) { FactoryBot.build(:ext_management_system) }
    let(:host) do
      FactoryBot.build(:host,
                        :ext_management_system => ems,
                        :ems_cluster           => FactoryBot.build(:ems_cluster))
    end
    it "clears ems and cluster" do
      host.disconnect_ems(ems)
      expect(host.ext_management_system).to be_nil
      expect(host.ems_cluster).to be_nil
    end

    it "doesnt clear the wrong ems" do
      host.disconnect_ems(FactoryBot.build(:ext_management_system))
      expect(host.ext_management_system).not_to be_nil
      expect(host.ems_cluster).not_to be_nil
    end
  end

  describe "#v_total_storages" do
    it "counts" do
      host = FactoryBot.create(:host)
      host.storages.create(FactoryBot.attributes_for(:storage))
      expect(host.v_total_storages).to eq(1)
    end
  end

  describe "#v_total_vms" do
    it "counts" do
      host = FactoryBot.create(:host)
      FactoryBot.create(:vm, :host => host)
      expect(host.v_total_vms).to eq(1)
      expect(Host.attribute_supported_by_sql?(:v_total_vms)).to be true
    end
  end

  describe "#v_total_miq_templates" do
    it "counts" do
      host = FactoryBot.create(:host)
      FactoryBot.create(:template, :host => host)
      expect(host.v_total_miq_templates).to eq(1)
      expect(Host.attribute_supported_by_sql?(:v_total_miq_templates)).to be true
    end
  end

  describe "#v_annotation" do
    it "handles nil" do
      h = FactoryBot.build(:host)
      expect(h.v_annotation).to be_nil
    end

    it "delegates" do
      h = FactoryBot.build(:host, :hardware => FactoryBot.build(:hardware, :annotation => "the annotation"))
      expect(h.v_annotation).to eq("the annotation")
    end
  end

  describe "#v_owning_cluster" do
    it "handles nil" do
      h = FactoryBot.build(:host)
      expect(h.v_owning_cluster).to eq("")
    end

    it "delegates" do
      h = FactoryBot.build(:host, :ems_cluster => FactoryBot.build(:ems_cluster, :name => "the cluster"))
      expect(h.v_owning_cluster).to eq("the cluster")
    end
  end

  describe "#ram_size" do
    it "handles nil" do
      h = FactoryBot.build(:host)
      expect(h.ram_size).to eq(0)
    end

    it "delegates" do
      h = FactoryBot.build(:host, :hardware => FactoryBot.build(:hardware, :memory_mb => 100))
      expect(h.ram_size).to eq(100)
    end
  end

  describe "#cpu_total_cores", "#total_vcpus" do
    it "handles nil" do
      h = FactoryBot.build(:host)
      expect(h.cpu_total_cores).to eq(0)
      expect(h.total_vcpus).to eq(0)
    end

    it "delegates" do
      h = FactoryBot.build(:host, :hardware => FactoryBot.build(:hardware, :cpu_total_cores => 4))
      expect(h.cpu_total_cores).to eq(4)
      expect(h.total_vcpus).to eq(4)
    end
  end

  describe "#num_cpu" do
    it "handles nil" do
      h = FactoryBot.build(:host)
      expect(h.num_cpu).to eq(0)
    end

    it "delegates" do
      h = FactoryBot.build(:host, :hardware => FactoryBot.build(:hardware, :cpu_sockets => 3))
      expect(h.num_cpu).to eq(3)
    end
  end

  describe "#cpu_cores_per_socket" do
    it "handles nil" do
      h = FactoryBot.build(:host)
      expect(h.cpu_cores_per_socket).to eq(0)
    end

    it "delegates" do
      h = FactoryBot.build(:host, :hardware => FactoryBot.build(:hardware, :cpu_cores_per_socket => 4))
      expect(h.cpu_cores_per_socket).to eq(4)
    end
  end

  context "supported features" do
    it "does not support refresh_network_interfaces" do
      host = FactoryBot.build(:host)
      expect(host.supports_refresh_network_interfaces?).to be_falsey
    end
  end

  describe "#authentication_check_role" do
    it "returns smartstate" do
      host = FactoryBot.build(:host)
      expect(host.authentication_check_role).to eq('smartstate')
    end
  end

  describe "#validate_power_state" do
    let(:host) do
      FactoryBot.create(:host_vmware_esx,
                         :ext_management_system => FactoryBot.create(:ems_vmware),
                         :vmm_vendor            => 'vmware')
    end

    context "when host power state equal to pstate" do
      it "returns nil" do
        expect(host.validate_power_state('on')).to be_nil
        expect(host.validate_power_state(['on'])).to be_nil
      end
    end

    context "when host power state does not equal to pstate" do
      it "returns available false" do
        expect(host.validate_power_state('off')).to eq(:available => false,
                                                       :message   => "The Host is not powered 'off'")
        expect(host.validate_power_state(['off'])).to eq(:available => false,
                                                         :message   => "The Host is not powered [\"off\"]")
      end
    end
  end

  context "vmotion validation methods" do
    let(:host) do
      FactoryBot.create(:host_vmware_esx,
                         :ext_management_system => FactoryBot.create(:ems_vmware),
                         :vmm_vendor            => 'vmware')
    end

    describe "#validate_enable_vmotion" do
      it "returns available true" do
        expect(host.validate_enable_vmotion).to eq(:available => true, :message => nil)
      end
    end

    describe "#validate_disable_vmotion" do
      it "returns available true" do
        expect(host.validate_disable_vmotion).to eq(:available => true, :message => nil)
      end
    end

    describe "#validate_vmotion_enabled?" do
      it "returns available true" do
        expect(host.validate_vmotion_enabled?).to eq(:available => true, :message => nil)
      end
    end
  end

  describe "#validate_ipmi" do
    subject { host.validate_ipmi }

    context "host does not have ipmi address" do
      let(:host) { FactoryBot.create(:host) }

      it "returns available false" do
        expect(subject).to eq(:available => false, :message => "The Host is not configured for IPMI")
      end
    end

    context "host has ipmi address" do
      let(:host) { FactoryBot.create(:host, :ipmi_address => "127.0.0.1") }
      before do
        EvmSpecHelper.local_miq_server
      end

      context "host does not have ipmi credentials" do
        it "returns available false" do
          expect(subject).to eq(:available => false, :message => "The Host has no IPMI credentials")
        end
      end

      context "host has incorrect ipmi credentials" do
        it "returns available false" do
          host.update_authentication(:ipmi => {:password => "a"})
          expect(subject).to eq(:available => false, :message => "The Host has invalid IPMI credentials")
        end
      end

      context "host has correct ipmi credentials" do
        it "returns available true" do
          host.update_authentication(:ipmi => {:userid => "a", :password => "a"})
          expect(subject).to eq(:available => true, :message => nil)
        end
      end
    end
  end

  context "ipmi validation methods" do
    let(:host_with_ipmi) { FactoryBot.create(:host_with_ipmi) }
    before do
      EvmSpecHelper.local_miq_server
    end

    describe "#validate_start" do
      let(:host_off) { FactoryBot.create(:host_with_ipmi, :power_state => 'off') }

      it "returns available true" do
        expect(host_off.validate_start).to eq(:available => true, :message => nil)
      end
    end

    describe "#validate_stop" do
      it "returns available true" do
        expect(host_with_ipmi.validate_stop).to eq(:available => true, :message => nil)
      end
    end

    describe "#supports_reset" do
      it "returns true for supports_reset?" do
        expect(host_with_ipmi.supports_reset?).to be_truthy
      end
    end
  end

  describe ".clustered" do
    let(:host_with_cluster) { FactoryBot.create(:host, :ems_cluster => FactoryBot.create(:ems_cluster)) }
    let(:host) { FactoryBot.create(:host) }

    it "detects clustered hosts" do
      host_with_cluster
      host

      expect(Host.clustered).to eq([host_with_cluster])
    end
  end

  describe ".non_clustered" do
    let(:host_with_cluster) { FactoryBot.create(:host, :ems_cluster => FactoryBot.create(:ems_cluster)) }
    let(:host) { FactoryBot.create(:host) }

    it "detects non_clustered hosts" do
      host_with_cluster
      host

      expect(Host.non_clustered).to eq([host])
    end
  end

  describe "#scan" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryBot.create(:host_vmware)
      FactoryBot.create(:miq_event_definition, :name => :request_host_scan)
      # admin user is needed to process Events
      User.super_admin || FactoryBot.create(:user_with_group, :userid => "admin")
    end

    it "policy passes" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Host).to receive(:scan_queue)

      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @host.scan
      status, message, result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, result)
    end

    it "policy prevented" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Host).to_not receive(:scan_queue)

      event = {:attributes => {"full_data" => {:policy => {:prevented => true}}}}
      allow_any_instance_of(MiqAeEngine::MiqAeWorkspaceRuntime).to receive(:get_obj_from_path).with("/").and_return(:event_stream => event)
      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @host.scan
      status, message, _result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, MiqAeEngine::MiqAeWorkspaceRuntime.new)
    end
  end

  describe "#scan_queue" do
    let(:host) { FactoryBot.create(:host_vmware, :ext_management_system => ems) }

    before do
      MiqRegion.seed
      Zone.seed
    end

    context "when the EMS is paused" do
      let(:ems) { FactoryBot.create(:ems_infra, :name => "My Provider", :zone => Zone.maintenance_zone, :enabled => false) }

      it 'creates task with Error status when EMS paused' do
        expect(MiqQueue).not_to receive(:put)

        host.scan_queue
        task = MiqTask.first
        expect(task.status_error?).to eq(true)
        expect(task.message).to eq("#{ems.name} is paused")
      end
    end

    context "when the EMS is active" do
      let(:ems) { FactoryBot.create(:ems_infra, :name => "My Provider", :zone => Zone.default_zone) }
      it 'creates task with valid status EMS active' do
        allow(MiqQueue).to receive(:put).and_return(double)

        host.scan_queue
        task = MiqTask.first
        expect(task.status_ok?).to eq(true)
      end
    end
  end

  context "#refresh_linux_packages" do
    it "with utf-8 characters (like trademark)" do
      rpm_list = "iwl3945-firmware|15.32.2.9|noarch|System Environment/Kernel|43.el7|Firmware for Intel® PRO/Wireless 3945 A/B/G network adaptors"
      mock_ssu = double("SSU", :shell_exec => rpm_list)

      expect(GuestApplication).to receive(:add_elements) do |_host, xml|
        require 'nokogiri'
        expect(Nokogiri::Slop(xml.to_s).miq.software.applications.children.first.attributes["description"].value).to eq(
          "Firmware for Intel® PRO/Wireless 3945 A/B/G network adaptors"
        )
      end

      described_class.new.refresh_linux_packages(mock_ssu)
    end
  end

  context "#ipmi_config_valid?" do
    it "false if no IPMI address" do
      expect(described_class.new.ipmi_config_valid?).to eq(false)
    end

    it "false if address but no ipmi credentials" do
      expect(described_class.new(:ipmi_address => "127.0.0.1").ipmi_config_valid?).to eq(false)
    end

    it "true with address and credentials but not including mac_addr" do
      EvmSpecHelper.local_miq_server # because of the authentication change
      expect(FactoryBot.create(:host_with_ipmi).ipmi_config_valid?).to eq(true)
    end

    it "false with address, credentials and include_mac_addr with blank address" do
      EvmSpecHelper.local_miq_server # because of the authentication change
      expect(FactoryBot.create(:host_with_ipmi, :mac_address => nil).ipmi_config_valid?(true)).to eq(false)
    end

    it "true with address, credentials and include_mac_addr with blank address" do
      EvmSpecHelper.local_miq_server # because of the authentication change
      expect(FactoryBot.create(:host_with_ipmi).ipmi_config_valid?(true)).to eq(true)
    end
  end
end
