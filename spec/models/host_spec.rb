describe Host do
  it "groups and users joins" do
    user1  = FactoryGirl.create(:account_user)
    user2  = FactoryGirl.create(:account_user)
    group  = FactoryGirl.create(:account_group)
    host1  = FactoryGirl.create(:host_vmware, :users => [user1], :groups => [group])
    host2  = FactoryGirl.create(:host_vmware, :users => [user2])
    expect(described_class.joins(:users)).to match_array([host1, host2])
    expect(described_class.joins(:groups)).to eq [host1]
    expect(described_class.joins(:users, :groups)).to eq [host1]
  end

  it "directories and files joins" do
    file1  = FactoryGirl.create(:filesystem, :rsc_type => "file")
    file2  = FactoryGirl.create(:filesystem, :rsc_type => "file")
    dir    = FactoryGirl.create(:filesystem, :rsc_type => "dir")
    host1  = FactoryGirl.create(:host_vmware, :files => [file1], :directories => [dir])
    host2  = FactoryGirl.create(:host_vmware, :files => [file2])
    expect(described_class.joins(:files)).to match_array([host1, host2])
    expect(described_class.joins(:directories)).to eq [host1]
    expect(described_class.joins(:files, :directories)).to eq [host1]
  end

  it "#ems_custom_attributes" do
    ems_attr   = FactoryGirl.create(:custom_attribute, :source => 'VC')
    other_attr = FactoryGirl.create(:custom_attribute, :source => 'NOTVC')
    host       = FactoryGirl.create(:host_vmware, :custom_attributes => [ems_attr, other_attr])
    expect(host.ems_custom_attributes).to eq [ems_attr]
  end

  it "#save_drift_state" do
    # TODO: Beef up with more data
    host = FactoryGirl.create(:host_vmware)
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
    cluster1 = FactoryGirl.create(:ems_cluster)
    host = FactoryGirl.build(:host_vmware, :ems_cluster => cluster1)
    expect(MiqEvent).to receive(:raise_evm_event).with(host, "host_add_to_cluster", anything)
    host.save

    # Existing host changes clusters
    cluster2 = FactoryGirl.create(:ems_cluster)
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
    let(:host) { FactoryGirl.build(:host_vmware) }
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
      @ems = FactoryGirl.create(:ext_management_system, :tenant => FactoryGirl.create(:tenant))
      @host = FactoryGirl.create(:host, :ems_id => @ems.id)
    end

    context "#start" do
      before do
        allow_any_instance_of(described_class).to receive_messages(:validate_start   => {})
        allow_any_instance_of(described_class).to receive_messages(:validate_ipmi    => {:available => true, :message => nil})
        allow_any_instance_of(described_class).to receive_messages(:run_ipmi_command => "off")
        FactoryGirl.create(:miq_event_definition, :name => :request_host_start)
        # admin user is needed to process Events
        FactoryGirl.create(:user_with_group, :userid => "admin", :name => "Administrator")
      end

      it "policy passes" do
        expect_any_instance_of(described_class).to receive(:ipmi_power_on)

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
    subject { FactoryGirl.build(:host) }

    it("#current_memory_usage") { expect(subject.current_memory_usage).to be_kind_of(Integer) }
    it("#current_cpu_usage")    { expect(subject.current_cpu_usage).to    be_kind_of(Integer) }
  end

  context "#vmm_vendor_display" do
    it("known vendor") { expect(FactoryGirl.build(:host_vmware_esx).vmm_vendor_display).to          eq("VMware") }
    it("nil vendor")   { expect(FactoryGirl.build(:host, :vmm_vendor => nil).vmm_vendor_display).to eq("Unknown") }
  end

  it ".host_discovery_types" do
    expect(Host.host_discovery_types).to match_array ["esx", "ipmi"]
  end

  it ".host_create_os_types" do
    expect(Host.host_create_os_types).to eq("VMware ESX" => "linux_generic")
  end

  context "host validation" do
    before do
      EvmSpecHelper.local_miq_server

      @password = "v2:{/OViaBJ0Ug+RSW9n7EFGqw==}"
      @host = FactoryGirl.create(:host_vmware_esx)
      @data = {:default => {:userid => "root", :password => @password}}
      @options = {:save => false}
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
    let(:os) { FactoryGirl.create(:operating_system) }
    subject  { FactoryGirl.create(:host, :operating_system => os) }

    before do
      FactoryGirl.create(:firewall_rule, :host_protocol => 'udp', :direction => "in", :enabled => true, :port => 1001, :resource => os)
      FactoryGirl.create(:firewall_rule, :host_protocol => 'udp', :direction => "out", :enabled => true, :port => 1002, :resource => os)
      FactoryGirl.create(:firewall_rule, :host_protocol => 'tcp', :direction => "in", :enabled => true, :port => 1003, :resource => os)
    end

    it("#enabled_udp_outbound_ports") { expect(subject.enabled_udp_outbound_ports).to match_array([1002]) }
    it("#enabled_inbound_ports")      { expect(subject.enabled_inbound_ports).to      match_array([1003, 1001]) }
  end

  context ".node_types" do
    it "returns :mixed_hosts when there are both openstack & non-openstack hosts in db" do
      FactoryGirl.create(:host_openstack_infra, :ext_management_system => FactoryGirl.create(:ems_openstack_infra))
      FactoryGirl.create(:host_vmware_esx,      :ext_management_system => FactoryGirl.create(:ems_vmware))

      expect(Host.node_types).to eq(:mixed_hosts)
    end

    it "returns :openstack when there are only openstack hosts in db" do
      FactoryGirl.create(:host_openstack_infra, :ext_management_system => FactoryGirl.create(:ems_openstack_infra))

      expect(Host.node_types).to eq(:openstack)
    end

    it "returns :non_openstack when there are non-openstack hosts in db" do
      FactoryGirl.create(:host_vmware_esx, :ext_management_system => FactoryGirl.create(:ems_vmware))

      expect(Host.node_types).to eq(:non_openstack)
    end
  end

  context "#openstack_host?" do
    it("false") { expect(FactoryGirl.build(:host).openstack_host?).to be false }

    it "true" do
      expect(FactoryGirl.build(:host_openstack_infra, :ext_management_system => FactoryGirl.create(:ems_openstack_infra))).to be_openstack_host
    end
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
    let(:admin)    { FactoryGirl.create(:user_with_group, :userid => "admin") }
    let(:tenant)   { FactoryGirl.create(:tenant) }
    let(:ems)      { FactoryGirl.create(:ext_management_system, :tenant => tenant) }
    before         { admin }

    subject        { @host.tenant_identity }

    it "has tenant from provider" do
      @host = FactoryGirl.create(:host, :ext_management_system => ems)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(ems.tenant.default_miq_group)
      expect(subject.current_tenant).to eq(ems.tenant)
    end

    it "without a provider, has tenant from root tenant" do
      @host = FactoryGirl.create(:host)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(Tenant.root_tenant.default_miq_group)
      expect(subject.current_tenant).to eq(Tenant.root_tenant)
    end
  end

  describe "#disconnect_ems" do
    let(:ems) { FactoryGirl.build(:ext_management_system) }
    let(:host) do
      FactoryGirl.build(:host,
                        :ext_management_system => ems,
                        :ems_cluster           => FactoryGirl.build(:ems_cluster))
    end
    it "clears ems and cluster" do
      host.disconnect_ems(ems)
      expect(host.ext_management_system).to be_nil
      expect(host.ems_cluster).to be_nil
    end

    it "doesnt clear the wrong ems" do
      host.disconnect_ems(FactoryGirl.build(:ext_management_system))
      expect(host.ext_management_system).not_to be_nil
      expect(host.ems_cluster).not_to be_nil
    end
  end

  describe "#v_total_storages" do
    it "counts" do
      host = FactoryGirl.create(:host)
      host.storages.create(FactoryGirl.attributes_for(:storage))
      expect(host.v_total_storages).to eq(1)
      expect(Host.attribute_supported_by_sql?(:v_total_storages)).to be false
    end
  end

  describe "#v_total_vms" do
    it "counts" do
      host = FactoryGirl.create(:host)
      FactoryGirl.create(:vm, :host => host)
      expect(host.v_total_vms).to eq(1)
      expect(Host.attribute_supported_by_sql?(:v_total_vms)).to be true
    end
  end

  describe "#v_total_miq_templates" do
    it "counts" do
      host = FactoryGirl.create(:host)
      FactoryGirl.create(:template, :host => host)
      expect(host.v_total_miq_templates).to eq(1)
      expect(Host.attribute_supported_by_sql?(:v_total_miq_templates)).to be true
    end
  end

  describe "#v_annotation" do
    it "handles nil" do
      h = FactoryGirl.build(:host)
      expect(h.v_annotation).to be_nil
    end

    it "delegates" do
      h = FactoryGirl.build(:host, :hardware => FactoryGirl.build(:hardware, :annotation => "the annotation"))
      expect(h.v_annotation).to eq("the annotation")
    end
  end

  describe "#v_owning_cluster" do
    it "handles nil" do
      h = FactoryGirl.build(:host)
      expect(h.v_owning_cluster).to eq("")
    end

    it "delegates" do
      h = FactoryGirl.build(:host, :ems_cluster => FactoryGirl.build(:ems_cluster, :name => "the cluster"))
      expect(h.v_owning_cluster).to eq("the cluster")
    end
  end

  describe "#ram_size" do
    it "handles nil" do
      h = FactoryGirl.build(:host)
      expect(h.ram_size).to eq(0)
    end

    it "delegates" do
      h = FactoryGirl.build(:host, :hardware => FactoryGirl.build(:hardware, :memory_mb => 100))
      expect(h.ram_size).to eq(100)
    end
  end

  describe "#cpu_total_cores", "#total_vcpus" do
    it "handles nil" do
      h = FactoryGirl.build(:host)
      expect(h.cpu_total_cores).to eq(0)
      expect(h.total_vcpus).to eq(0)
    end

    it "delegates" do
      h = FactoryGirl.build(:host, :hardware => FactoryGirl.build(:hardware, :cpu_total_cores => 4))
      expect(h.cpu_total_cores).to eq(4)
      expect(h.total_vcpus).to eq(4)
    end
  end

  describe "#num_cpu" do
    it "handles nil" do
      h = FactoryGirl.build(:host)
      expect(h.num_cpu).to eq(0)
    end

    it "delegates" do
      h = FactoryGirl.build(:host, :hardware => FactoryGirl.build(:hardware, :cpu_sockets => 3))
      expect(h.num_cpu).to eq(3)
    end
  end

  describe "#cpu_cores_per_socket" do
    it "handles nil" do
      h = FactoryGirl.build(:host)
      expect(h.cpu_cores_per_socket).to eq(0)
    end

    it "delegates" do
      h = FactoryGirl.build(:host, :hardware => FactoryGirl.build(:hardware, :cpu_cores_per_socket => 4))
      expect(h.cpu_cores_per_socket).to eq(4)
    end
  end

  context "supported features" do
    it "does not support refresh_network_interfaces" do
      host = FactoryGirl.build(:host)
      expect(host.supports_refresh_network_interfaces?).to be_falsey
    end
  end
end
