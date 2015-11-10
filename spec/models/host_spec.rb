require "spec_helper"

describe Host do
  it "#save_drift_state" do
    # TODO: Beef up with more data
    host = FactoryGirl.create(:host_vmware)
    host.save_drift_state

    host.drift_states.size.should == 1
    DriftState.count.should == 1

    host.drift_states.first.data.should == {
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
    }
  end

  it "emits cluster policy event when the cluster changes" do
    # New host added to a cluster
    cluster1 = FactoryGirl.create(:ems_cluster)
    host = FactoryGirl.create(:host_vmware)
    host.ems_cluster = cluster1
    MiqEvent.should_receive(:raise_evm_event).with(host, "host_add_to_cluster", anything)
    host.save

    # Existing host changes clusters
    cluster2 = FactoryGirl.create(:ems_cluster)
    host.ems_cluster = cluster2
    MiqEvent.should_receive(:raise_evm_event).with(host, "host_remove_from_cluster", hash_including(:ems_cluster => cluster1))
    MiqEvent.should_receive(:raise_evm_event).with(host, "host_add_to_cluster", hash_including(:ems_cluster => cluster2))
    host.save

    # Existing host becomes cluster-less
    host.ems_cluster = nil
    MiqEvent.should_receive(:raise_evm_event).with(host, "host_remove_from_cluster", hash_including(:ems_cluster => cluster2))
    host.save
  end

  context "#scannable_status" do
    before do
      Authentication.any_instance.stub(:after_authentication_changed)
      @host = FactoryGirl.create(:host_vmware)
      @host.stub(:refreshable_status => {:show => false, :enabled => false})
    end

    it "refreshable_status already reporting error" do
      reportable_status = {:show => true, :enabled => false, :message => "Proxy not active"}
      @host.stub(:refreshable_status => reportable_status)
      @host.scannable_status.should == reportable_status
    end

    it "ipmi address and creds" do
      @host.update_attribute(:ipmi_address, "127.0.0.1")
      @host.update_authentication({:ipmi => {:userid => "a", :password => "a"}})
      @host.scannable_status.should == {:show => true, :enabled => true, :message => ""}
    end

    it "ipmi address but no creds" do
      @host.update_attribute(:ipmi_address, "127.0.0.1")
      @host.scannable_status.should == {:show => true, :enabled => false, :message => "Provide credentials for IPMI"}
    end

    it "creds but no ipmi address" do
      @host.update_authentication({:ipmi => {:userid => "a", :password => "a"}})
      @host.scannable_status.should == {:show => true, :enabled => false, :message => "Provide an IPMI Address"}
    end

    it "no creds or ipmi address" do
      @host.scannable_status.should == {:show => true, :enabled => false, :message => "Provide an IPMI Address"}
    end
  end

  context ".check_for_vms_to_scan" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      @zone2 = FactoryGirl.create(:small_environment)

      Host.any_instance.stub(:scan_frequency).and_return(30)
    end

    it "in zone1 will only scan Vms in zone1" do
      should_only_scan_in_its_zone(@zone1)
    end

    it "in zone2 will only scan Vms in zone2" do
      should_only_scan_in_its_zone(@zone2)
    end

    def should_only_scan_in_its_zone(zone)
      vms = zone.vms_and_templates
      MiqServer.stub(:my_server).and_return(zone.miq_servers.first)
      Host.check_for_vms_to_scan
      jobs = Job.where(:target_class => 'VmOrTemplate')
      jobs.length.should == 2
      jobs.collect(&:target_id).should match_array vms.collect(&:id)
    end
  end

  context "power operations" do
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ext_management_system, :tenant => FactoryGirl.create(:tenant))
      @host = FactoryGirl.create(:host, :ems_id => @ems.id)
    end

    context "#start" do
      before do
        described_class.any_instance.stub(:validate_start   => {})
        described_class.any_instance.stub(:validate_ipmi    => {:available => true, :message => nil})
        described_class.any_instance.stub(:run_ipmi_command => "off")
        FactoryGirl.create(:miq_event_definition, :name => :request_host_start)
        # admin user is needed to process Events
        FactoryGirl.create(:user_with_group, :userid => "admin", :name => "Administrator")
      end

      it "policy passes" do
        described_class.any_instance.should_receive(:ipmi_power_on)

        @host.start
        status, message, result = MiqQueue.first.deliver
        MiqQueue.first.delivered(status, message, result)
      end

      it "policy prevented" do
        described_class.any_instance.should_not_receive(:ipmi_power_on)

        event = {:attributes => {"full_data" => {:policy => {:pprevented => true}}}}
        MiqAeEngine::MiqAeWorkspaceRuntime.any_instance.stub(:get_obj_from_path).with("/").and_return(:event_stream => event)
        @host.start
        status, message, _result = MiqQueue.first.deliver
        MiqQueue.first.delivered(status, message, MiqAeEngine::MiqAeWorkspaceRuntime.new)
      end
    end

    context "with shutdown invalid" do
      it "#validate_shutdown" do
        msg = @host.validate_shutdown
        msg.should be_kind_of(Hash)
        msg[:available].should be_false
        msg[:message].should   be_kind_of(String)
      end

      it "#shutdown" do
        -> { @host.shutdown }.should_not raise_error
      end
    end

    context "with reboot invalid" do
      it "#validate_reboot" do
        msg = @host.validate_reboot
        msg.should be_kind_of(Hash)
        msg[:available].should be_false
        msg[:message].should   be_kind_of(String)
      end

      it "#reboot" do
        -> { @host.reboot }.should_not raise_error
      end
    end

    context "with standby invalid" do
      it "#validate_standby" do
        msg = @host.validate_standby
        msg.should be_kind_of(Hash)
        msg[:available].should be_false
        msg[:message].should   be_kind_of(String)
      end

      it "#standby" do
        -> { @host.standby }.should_not raise_error
      end
    end

    context "with enter_maint_mode invalid" do
      it "#validate_enter_maint_mode" do
        msg = @host.validate_enter_maint_mode
        msg.should be_kind_of(Hash)
        msg[:available].should be_false
        msg[:message].should   be_kind_of(String)
      end

      it "#enter_maint_mode" do
        -> { @host.enter_maint_mode }.should_not raise_error
      end
    end

    context "with exit_maint_mode invalid" do
      it "#validate_exit_maint_mode" do
        msg = @host.validate_exit_maint_mode
        msg.should be_kind_of(Hash)
        msg[:available].should be_false
        msg[:message].should   be_kind_of(String)
      end

      it "#exit_maint_mode" do
        -> { @host.exit_maint_mode }.should_not raise_error
      end
    end
  end

  context "quick statistics retrieval" do
    before(:each) do
      @host = FactoryGirl.create(:host)
    end

    it "#current_memory_usage" do
      mem_usage = @host.current_memory_usage
      mem_usage.should be_an(Integer)

      -> { @host.current_memory_usage }.should_not raise_error
    end

    it "#current_cpu_usage" do
      cpu_usage = @host.current_cpu_usage
      cpu_usage.should be_an(Integer)

      -> { @host.current_cpu_usage }.should_not raise_error
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
    context "when database has 3 part FQDN, " do
      before do
        @fqdn_hostname            = "test1.fake.com"
        @partial_hostname         = "test1"
        @bad_fqdn_hostname        = "test1.dummy.com"
        @bad_partial_hostname     = "test"
        @ipaddress                = "1.1.1.1"
        @host = FactoryGirl.create(:host_vmware, :hostname => @fqdn_hostname, :ipaddress => @ipaddress)
      end

      it "with exact hostname and IP" do
        Host.lookUpHost(@fqdn_hostname, @ipaddress).should == @host
      end

      it "with exact hostname and updated IP" do
        Host.lookUpHost(@fqdn_hostname, "2.2.2.2").should == @host
      end

      it "with exact IP and updated hostname" do
        Host.lookUpHost("not_it.test.com", @ipaddress).should == @host
      end

      it "with exact IP only" do
        Host.lookUpHost(nil, @ipaddress).should == @host
      end

      it "with hostname only" do
        Host.lookUpHost(@fqdn_hostname, nil).should == @host
      end

      it "with partial hostname only" do
        Host.lookUpHost(@partial_hostname, nil).should == @host
      end

      it "with bad fqdn hostname only" do
        Host.lookUpHost(@bad_fqdn_hostname, nil).should be_nil
      end

      it "with bad partial hostname only" do
        Host.lookUpHost(@bad_partial_hostname, nil).should be_nil
      end
    end

    context "when database has 4+ part FQDN, " do
      before do
        @fqdn_hostname               = "test1.dummy.fake.com"
        @partial_hostname_multi      = "test1.dummy"
        @partial_hostname_single     = "test1"
        @bad_fqdn_hostname           = "test1.something.fake.com"
        @bad_partial_hostname_multi  = "test1.something"
        @ipaddress                   = "1.1.1.1"
        @host = FactoryGirl.create(:host_vmware, :hostname => @fqdn_hostname, :ipaddress => @ipaddress)
      end

      it "with exact hostname and IP" do
        Host.lookUpHost(@fqdn_hostname, @ipaddress).should == @host
      end

      it "with exact hostname and updated IP" do
        Host.lookUpHost(@fqdn_hostname, "2.2.2.2").should == @host
      end

      it "with exact IP and updated hostname" do
        Host.lookUpHost("not_it.dummy.test.com", @ipaddress).should == @host
      end

      it "with exact IP only" do
        Host.lookUpHost(nil, @ipaddress).should == @host
      end

      it "with exact hostname only" do
        Host.lookUpHost(@fqdn_hostname, nil).should == @host
      end

      it "with partial hostname (multi part) only" do
        Host.lookUpHost(@partial_hostname_multi, nil).should == @host
      end

      it "with partial hostname (single part) only" do
        Host.lookUpHost(@partial_hostname_single, nil).should == @host
      end

      it "with bad fqdn hostname only" do
        Host.lookUpHost(@bad_fqdn_hostname, nil).should be_nil
      end

      it "with bad partial hostname (multi part) only" do
        Host.lookUpHost(@bad_partial_hostname_multi, nil).should be_nil
      end
    end
    context "when hosts have duplicate hostnames" do
      before do
        @fqdn_hostname            = "test1.fake.com"
        @ipaddress_1              = "1.1.1.1"
        @ipaddress_2              = "2.2.2.2"
        @ems_id_1                 = 1
        @ems_id_2                 = 2
        @ems_ref_1                = "host-1"
        @ems_ref_2                = "host-2"
        @host = FactoryGirl.create(:host_vmware, :hostname => @fqdn_hostname, :ipaddress => @ipaddress_1,
                                   :ems_ref => @ems_ref_1, :ems_id => @ems_id_1)
      end
      it "with only fqdn and ipaddress" do
        Host.lookUpHost(@fqdn_hostname, @ipaddress_1).should == @host
      end
      it "with fqdn, ipaddress, and ems_ref finds right host" do
        Host.lookUpHost(@fqdn_hostname, @ipaddress_1, :ems_ref => @ems_ref_1).should == @host
      end
      it "with fqdn, ipaddress, and different ems_ref returns nil" do
        Host.lookUpHost(@fqdn_hostname, @ipaddress_2, :ems_ref => @ems_ref_2).should be_nil
      end
      it "with ems_ref and ems_id" do
        Host.lookUpHost(@fqdn_hostname, @ipaddress_1, :ems_ref => @ems_ref_1, :ems_id => @ems_id_1).should == @host
      end
      it "with ems_ref and other ems_id" do
        Host.lookUpHost(@fqdn_hostname, @ipaddress_1, :ems_ref => @ems_ref_1, :ems_id => @ems_id_2).should be_nil
      end
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
        @host.authentications.count.should eq(1)
      end

      it "validate" do
        @host.stub(:connect_ssh)
        assert_default_credentials_validated
        @host.authentications.count.should eq(0)
      end
    end

    context "default and remote credentials" do
      it "save default, then save remote" do
        @host.update_authentication(@data, @options)
        @host.save
        @host.authentications.count.should eq(1)

        @data[:remote] = {:userid => "root", :password => @password}
        @host.update_authentication(@data, @options)
        @host.save
        @host.authentications.count.should eq(2)
      end

      it "save both together" do
        @data[:remote] = {:userid => "root", :password => @password}
        @host.update_authentication(@data, @options)
        @host.save
        @host.authentications.count.should eq(2)
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
        @host.stub(:connect_ssh)
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
      @host.enabled_udp_outbound_ports.should match_array([1002])
    end

    it "#enabled_inbound_ports" do
      @host.enabled_inbound_ports.should match_array([1003, 1001])
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
      result.should eq(:mixed_hosts)
    end

    it "returns :openstack when there are only openstack hosts in db" do
      FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)
      result = Host.node_types
      result.should eq(:openstack)
    end

    it "returns :non_openstack when there are non-openstack hosts in db" do
      FactoryGirl.create(:host_vmware_esx, :ems_id => @ems1.id)
      result = Host.node_types
      result.should eq(:non_openstack)
    end
  end

  context "#openstack_host?" do
    it "returns true for openstack host" do
      ems = FactoryGirl.create(:ems_openstack_infra)
      host = FactoryGirl.create(:host_redhat, :ems_id => ems.id)

      result = host.openstack_host?
      result.should be_true
    end

    it "returns false for non-openstack host" do
      ems = FactoryGirl.create(:ems_vmware)
      host = FactoryGirl.create(:host_vmware_esx, :ems_id => ems.id)
      result = host.openstack_host?
      result.should be_false
    end
  end

  def assert_default_credentials_validated
    @host.stub(:verify_credentials_with_ws)
    @host.update_authentication(@data, @options)
    @host.verify_credentials(:default).should be_true
  end

  def assert_remote_credentials_validated
    @host.stub(:connect_ssh)
    @host.update_authentication(@data, @options)
    @host.verify_credentials(:remote).should be_true
  end
end
