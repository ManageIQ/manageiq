require "spec_helper"

describe Zone do
  context "with two small envs" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      @host1 = @zone1.ext_management_systems.first.hosts.first
      @zone1.reload
      @zone2 = FactoryGirl.create(:small_environment)
      @host2 = @zone2.ext_management_systems.first.hosts.first
      @zone2.reload
    end

    it "zone1#hosts will return hosts in zone1" do
      @zone1.hosts.should have_same_elements([@host1])
    end

    it "zone2#hosts will return hosts in zone2" do
      @zone2.hosts.should have_same_elements([@host2])
    end

    it "zone1#vms will return vms in zone1" do
      @zone1.vms.should have_same_elements(@host1.vms)
    end

    it "zone2#vms will return vms in zone2" do
      @zone2.vms.should have_same_elements(@host2.vms)
    end

    it "zone1#miq_proxies will be empty due to no proxies" do
      @zone1.miq_proxies.should be_empty
    end

    it "zone2#miq_proxies will be empty due to no proxies" do
      @zone2.miq_proxies.should be_empty
    end

    it "hosts in virtual reflections" do
      described_class.all(:include => :aggregate_cpu_speed).should_not be_nil
    end

    it "vms_and_templates in virtual reflections" do
      described_class.all(:include => :aggregate_vm_cpus).should_not be_nil
    end

    context "with proxies in different zones" do
      before(:each) do
        @proxy1 = FactoryGirl.create(:active_cos_proxy)
        @proxy1.host = @zone1.hosts.first
        @proxy1.save

        @proxy2 = FactoryGirl.create(:active_cos_proxy)
        @proxy2.host = @zone2.hosts.first
        @proxy2.save
      end

      it "zone1#miq_proxies will return proxy1" do
        @zone1.miq_proxies.should == [@proxy1]
      end

      it "zone2#miq_proxies will return proxy2" do
        @zone2.miq_proxies.should == [@proxy2]
      end
    end
  end

  context "when dealing with clouds" do

    before :each do
      guid, server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    end

    it "returns the set of ems_clouds" do
      ems_clouds = []
      2.times { ems_clouds << FactoryGirl.create(:ems_openstack, :zone => @zone) }
      2.times { ems_clouds << FactoryGirl.create(:ems_amazon, :zone => @zone) }
      ems_infra = FactoryGirl.create(:ems_vmware, :zone => @zone)

      zone_clouds = @zone.ems_clouds
      zone_clouds.should =~ ems_clouds

      zone_clouds.should_not include ems_infra
    end

    it "returns the set of availability_zones" do
      openstack = FactoryGirl.create(:ems_openstack, :zone => @zone)
      azs = []
      3.times { azs << FactoryGirl.create(:availability_zone, :ems_id => openstack.id) }

      @zone.availability_zones.should =~ azs
    end

    it "returns the set of vms_without_availability_zones" do
      openstacks = [FactoryGirl.create(:ems_openstack, :zone => @zone),
                    FactoryGirl.create(:ems_openstack, :zone => @zone)]
      azs        = [FactoryGirl.create(:availability_zone, :ems_id => openstacks[0].id),
                    FactoryGirl.create(:availability_zone, :ems_id => openstacks[1].id)]
      vms_in_az = []
      vms_not_in_az = []
      2.times do
        vm = FactoryGirl.create(:vm_openstack)
        azs[0].vms << vm
        vms_in_az << vm
      end
      2.times do
        vm = FactoryGirl.create(:vm_openstack)
        azs[1].vms << vm
        vms_in_az << vm
      end
      3.times { vms_not_in_az << FactoryGirl.create(:vm_openstack, :ems_id => openstacks[0].id) }
      3.times { vms_not_in_az << FactoryGirl.create(:vm_openstack, :ems_id => openstacks[1].id) }

      @zone.vms_without_availability_zone.should =~ vms_not_in_az
    end
  end

  context ".determine_queue_zone" do
    subject           { described_class }

    before do
      ServerRole.stub(:region_scoped_roles => [ServerRole.new(:name => "inregion")])
      MiqServer.stub(:my_zone) { "myzone" }
    end

    context "with no zone specified" do
      it "no role specified should return server zone" do
        expect(subject.determine_queue_zone({})).to eq("myzone")
      end

      it "regional role specified should return ANY zone" do
        expect(subject.determine_queue_zone(:role => "inregion")).to be_nil
      end

      it "non-regional role specified should return server zone" do
        expect(subject.determine_queue_zone(:role => "anyregion")).to eq("myzone")
      end
    end
    context "with zone specified" do
      it "should return specified zone" do
        expect(subject.determine_queue_zone(:zone => "special", :role => "inregion")).to eq("special")
      end

      it "should return specified zone (even if nil)" do
        expect(subject.determine_queue_zone(:zone => nil, :role => "inregion")).to be_nil
      end
    end
  end

  context "#active?" do
    let(:zone) { described_class.new(:miq_servers => [miq_server]) }
    let(:miq_server) { MiqServer.new }

    it "true" do
      miq_server.stub(:active?).and_return(true)

      expect(zone.active?).to be_true
    end

    it "false" do
      miq_server.stub(:active?).and_return(false)

      expect(zone.active?).to be_false
    end
  end

  context "#ntp_settings" do
    let(:zone) { described_class.new }

    it "no settings returns default NTP settings" do
      expect(zone.ntp_settings).to eq(:server => ["0.pool.ntp.org", "1.pool.ntp.org", "2.pool.ntp.org"])
    end

    it "with :ntp key returns what was set" do
      zone.settings[:ntp] = {:server => ["tock.example.com"]}

      expect(zone.ntp_settings).to eq(:server => ["tock.example.com"])
    end
  end

  context "#after_save callback" do
    before do
      _, _, @zone = EvmSpecHelper.create_guid_miq_server_zone

      @zone.update_attributes(:settings => {:ntp => {:server => ["tick.example.com"]}})
      MiqQueue.where(:class_name => "MiqServer", :method_name => "ntp_reload").destroy_all
    end

    it "settings changed queues ntp reload" do
      described_class.any_instance.should_receive(:queue_ntp_reload_if_changed).once.and_call_original

      @zone.update_attributes(:settings => {:ntp => {:server => ["tock.example.com"]}})

      expect(MiqQueue.where(:class_name => "MiqServer", :method_name => "ntp_reload").count).to eq(1)
    end

    it "settings not changed does not queue ntp reload" do
      described_class.any_instance.should_receive(:queue_ntp_reload_if_changed).once.and_call_original

      @zone.update_attributes(:settings => {:ntp => {:server => ["tick.example.com"]}})

      expect(MiqQueue.where(:class_name => "MiqServer", :method_name => "ntp_reload").count).to eq(0)
    end
  end

  it "#settings should always be a hash" do
    expect(described_class.new.settings).to be_kind_of(Hash)
  end
end
