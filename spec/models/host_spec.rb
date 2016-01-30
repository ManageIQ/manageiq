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
      :class              => "ManageIQ::Providers::Vmware::InfraManager::Host",
      :id                 => host.id,
      :name               => host.name,
      :vmm_vendor         => "VMware",
      :v_total_vms        => 0,

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
    host = FactoryGirl.create(:host_vmware)
    host.ems_cluster = cluster1
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
    before(:each) do
      @host = FactoryGirl.create(:host)
    end

    it "#current_memory_usage" do
      mem_usage = @host.current_memory_usage
      expect(mem_usage).to be_an(Integer)

      expect { @host.current_memory_usage }.not_to raise_error
    end

    it "#current_cpu_usage" do
      cpu_usage = @host.current_cpu_usage
      expect(cpu_usage).to be_an(Integer)

      expect { @host.current_cpu_usage }.not_to raise_error
    end
  end

  context "#vmm_vendor" do
    it "with known host type" do
      expect(FactoryGirl.create(:host_vmware_esx).vmm_vendor).to eq("VMware")
    end

    it "with nil vendor" do
      expect(FactoryGirl.create(:host, :vmm_vendor => nil).vmm_vendor).to eq("Unknown")
    end
  end

  context ".lookUpHost" do
    let(:host_3_part_hostname)    { FactoryGirl.create(:host_vmware, :hostname => "test1.example.com",       :ipaddress => "192.168.1.1") }
    let(:host_4_part_hostname)    { FactoryGirl.create(:host_vmware, :hostname => "test2.dummy.example.com", :ipaddress => "192.168.1.2") }
    let(:host_duplicate_hostname) { FactoryGirl.create(:host_vmware, :hostname => "test2.example.com",       :ipaddress => "192.168.1.3", :ems_ref => "host-1", :ems_id => 1) }
    let(:host_no_ems_id)          { FactoryGirl.create(:host_vmware, :hostname => "test2.example.com",       :ipaddress => "192.168.1.4", :ems_ref => "host-2") }
    before do
      host_3_part_hostname
      host_4_part_hostname
      host_duplicate_hostname
      host_no_ems_id
    end

    it "with exact hostname and IP" do
      expect(Host.lookUpHost(host_3_part_hostname.hostname, host_3_part_hostname.ipaddress)).to eq(host_3_part_hostname)
      expect(Host.lookUpHost(host_4_part_hostname.hostname, host_4_part_hostname.ipaddress)).to eq(host_4_part_hostname)
    end

    it "with exact hostname and updated IP" do
      expect(Host.lookUpHost(host_3_part_hostname.hostname, "192.168.1.254")).to eq(host_3_part_hostname)
      expect(Host.lookUpHost(host_4_part_hostname.hostname, "192.168.1.254")).to eq(host_4_part_hostname)
    end

    it "with exact IP and updated hostname" do
      expect(Host.lookUpHost("not_it.example.com", host_3_part_hostname.ipaddress)).to       eq(host_3_part_hostname)
      expect(Host.lookUpHost("not_it.dummy.example.com", host_4_part_hostname.ipaddress)).to eq(host_4_part_hostname)
    end

    it "with exact IP only" do
      expect(Host.lookUpHost(nil, host_3_part_hostname.ipaddress)).to eq(host_3_part_hostname)
      expect(Host.lookUpHost(nil, host_4_part_hostname.ipaddress)).to eq(host_4_part_hostname)
    end

    it "with exact hostname only" do
      expect(Host.lookUpHost(host_3_part_hostname.hostname, nil)).to eq(host_3_part_hostname)
      expect(Host.lookUpHost(host_4_part_hostname.hostname, nil)).to eq(host_4_part_hostname)
    end

    it "with bad fqdn hostname only" do
      expect(Host.lookUpHost("test1.example.org", nil)).to           be_nil
      expect(Host.lookUpHost("test2.something.example.com", nil)).to be_nil
    end

    it "with bad partial hostname only" do
      expect(Host.lookUpHost("test", nil)).to            be_nil
      expect(Host.lookUpHost("test2.something", nil)).to be_nil
    end

    it "with partial hostname only" do
      expect(Host.lookUpHost("test1", nil)).to       eq(host_3_part_hostname)
      expect(Host.lookUpHost("test2.dummy", nil)).to eq(host_4_part_hostname)
    end

    it "with duplicate hostname and ipaddress" do
      expect(Host.lookUpHost(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress)).to eq(host_duplicate_hostname)
    end

    it "with fqdn, ipaddress, and ems_ref finds right host" do
      expect(Host.lookUpHost(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress, :ems_ref => host_duplicate_hostname.ems_ref)).to eq(host_duplicate_hostname)
    end

    it "with fqdn, ipaddress, and ems_ref finds right host without an ems_id (reconnect orphaned host)" do
      expect(Host.lookUpHost(host_no_ems_id.hostname, host_no_ems_id.ipaddress, :ems_ref => host_no_ems_id.ems_ref)).to eq(host_no_ems_id)
    end

    it "with fqdn, ipaddress, and different ems_ref returns nil" do
      expect(Host.lookUpHost(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress, :ems_ref => "dummy_ref")).to be_nil
    end

    it "with ems_ref and ems_id" do
      expect(Host.lookUpHost(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress, :ems_ref => host_duplicate_hostname.ems_ref, :ems_id => 1)).to eq(host_duplicate_hostname)
    end

    it "with ems_ref and other ems_id" do
      expect(Host.lookUpHost(host_duplicate_hostname.hostname, host_duplicate_hostname.ipaddress, :ems_ref => host_duplicate_hostname.ems_ref, :ems_id => 0)).to be_nil
    end
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
    before do
      @host = FactoryGirl.create(:host_vmware)
      os = FactoryGirl.create(:operating_system, :name => 'XUNIL')
      @host.operating_system = os
      fr1 = FactoryGirl.create(:firewall_rule, :name => 'fr1', :host_protocol => 'udp',
                               :direction => "in", :enabled => true, :port => 1001)
      fr2 = FactoryGirl.create(:firewall_rule, :name => 'fr2', :host_protocol => 'udp',
                               :direction => "out", :enabled => true, :port => 1002)
      fr3 = FactoryGirl.create(:firewall_rule, :name => 'fr3', :host_protocol => 'tcp',
                               :direction => "in", :enabled => true, :port => 1003)
      [fr1, fr2, fr3].each do |fr|
        fr.update_attributes(:resource_type => os.class.name, :resource_id => os.id)
      end
    end

    it "#enabled_udp_outbound_ports" do
      expect(@host.enabled_udp_outbound_ports).to match_array([1002])
    end

    it "#enabled_inbound_ports" do
      expect(@host.enabled_inbound_ports).to match_array([1003, 1001])
    end
  end

  context "#node_types" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns :mixed_hosts when there are both openstack & non-openstack hosts in db" do
      FactoryGirl.create(:host_vmware_esx, :ems_id => @ems1.id)
      FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)

      result = Host.node_types
      expect(result).to eq(:mixed_hosts)
    end

    it "returns :openstack when there are only openstack hosts in db" do
      FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)
      result = Host.node_types
      expect(result).to eq(:openstack)
    end

    it "returns :non_openstack when there are non-openstack hosts in db" do
      FactoryGirl.create(:host_vmware_esx, :ems_id => @ems1.id)
      result = Host.node_types
      expect(result).to eq(:non_openstack)
    end
  end

  context "#openstack_host?" do
    it "returns true for openstack host" do
      ems = FactoryGirl.create(:ems_openstack_infra)
      host = FactoryGirl.create(:host_redhat, :ems_id => ems.id)

      result = host.openstack_host?
      expect(result).to be_truthy
    end

    it "returns false for non-openstack host" do
      ems = FactoryGirl.create(:ems_vmware)
      host = FactoryGirl.create(:host_vmware_esx, :ems_id => ems.id)
      result = host.openstack_host?
      expect(result).to be_falsey
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
end
