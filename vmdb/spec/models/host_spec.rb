require "spec_helper"

describe Host do
  it "#save_drift_state" do
    #TODO: Beef up with more data
    host = FactoryGirl.create(:host_vmware)
    host.save_drift_state

    host.drift_states.size.should == 1
    DriftState.count.should == 1

    host.drift_states.first.data.should == {
      :class              => "HostVmware",
      :id                 => host.id,
      :name               => host.name,
      :vmm_vendor         => "VMware",
      :v_total_vms        => 0,

      :advanced_settings  => [],
      :groups             => [],
      :guest_applications => [],
      :lans               => [],
      :patches            => [],
      :switches           => [],
      :system_services    => [],
      :tags               => [],
      :users              => [],
      :vms                => [],
    }
  end

  it "emits cluster policy event when the cluster changes" do
    # New host added to a cluster
    cluster1 = FactoryGirl.create(:ems_cluster)
    host = FactoryGirl.create(:host_vmware)
    host.ems_cluster = cluster1
    MiqEvent.should_receive(:raise_evm_event).with(host, "host_add_to_cluster", anything())
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
      jobs = Job.all(:conditions => {:target_class => 'VmOrTemplate'})
      jobs.length.should == 2
      jobs.collect(&:target_id).should match_array vms.collect(&:id)
    end
  end

  context "power operations" do
    before(:each) do
      @host = FactoryGirl.create(:host)
    end

    context "#start" do
      before do
        described_class.any_instance.stub(:validate_start   => {})
        described_class.any_instance.stub(:validate_ipmi    => {:available=>true, :message=>nil})
        described_class.any_instance.stub(:run_ipmi_command => "off")
      end

      it "policy passes" do
        described_class.any_instance.should_receive(:ipmi_power_on)
        @host.start
      end

      it "policy prevented" do
        MiqEvent.should_receive(:raise_evm_event).and_raise(MiqException::PolicyPreventAction)
        described_class.any_instance.should_not_receive(:ipmi_power_on)
        @host.start
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
        lambda { @host.shutdown }.should_not raise_error
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
        lambda { @host.reboot }.should_not raise_error
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
        lambda { @host.standby }.should_not raise_error
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
        lambda { @host.enter_maint_mode }.should_not raise_error
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
        lambda { @host.exit_maint_mode }.should_not raise_error
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

      lambda { @host.current_memory_usage }.should_not raise_error
    end

    it "#current_cpu_usage" do
      cpu_usage = @host.current_cpu_usage
      cpu_usage.should be_an(Integer)

      lambda { @host.current_cpu_usage }.should_not raise_error
    end
  end

  context ".find_by_audit_for_rss" do
    before(:each) do
      @host = FactoryGirl.create(:host)
      @tag_ns = "/managed/lifecycles"
      @tag = "SmartProxy"
      @host.tag_with(@tag, :ns => @tag_ns)
      @event_name = "agent_settings_change"
      @audit_event = FactoryGirl.create(:audit_event, :event => @event_name, :target_class => "Host", :target_id => @host.id)
    end

    it "works when tags are not specified" do
      events = Host.find_by_audit_for_rss(@event_name)
      events.first.should have_attributes(@host.attributes.merge(@audit_event.attributes))

      events = Host.find_by_audit_for_rss("foobar")
      events.should be_empty
    end

    it "works when tags are specified" do
      events = Host.find_by_audit_for_rss(@event_name, :tags => @tag, :tags_include => "any", :tag_ns => @tag_ns)
      events.first.should have_attributes(@host.attributes.merge(@audit_event.attributes))

      events = Host.find_by_audit_for_rss("foobar", :tags => @tag, :tags_include => "any", :tag_ns => @tag_ns)
      events.should be_empty
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
  end

  it ".host_discovery_types" do
    expect(Host.host_discovery_types).to match_array ["esx", "ipmi"]
  end

  it ".host_create_os_types" do
    expect(Host.host_create_os_types).to eq("VMware ESX" => "linux_generic")
  end

  context "host validation" do
    before do
      @zone = FactoryGirl.create(:zone)
      @server = FactoryGirl.create(:miq_server, :zone => @zone)
      MiqServer.stub(:my_server).and_return(@server)

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
