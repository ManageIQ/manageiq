require "spec_helper"
require File.expand_path(File.join(Rails.root, "..", "lib", "util", "win32", "miq-powershell")) unless defined?(MiqPowerShell)

describe VdiFarm do
  context "with two small envs" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      @host1 = @zone1.ext_management_systems.first.hosts.first
      @zone1.reload
      @zone2 = FactoryGirl.create(:small_environment)
      @host2 = @zone2.ext_management_systems.first.hosts.first
      @zone2.reload
    end

    it "refresh_all_vdi_farms_timer from zone1 with no proxies will refresh nothing" do
      MiqServer.stub(:my_server).and_return(@zone1.miq_servers.first)

      VdiFarm.should_receive(:refresh_ems).never
      VdiFarm.refresh_all_vdi_farms_timer
    end

    context "a vdi farm with an active proxy in both zones" do
      before(:each) do
        @farm1 = FactoryGirl.create(:vdi_farm_citrix)
        @active1 = FactoryGirl.create(:active_cos_proxy)
        @active1.save
        @farm1.miq_proxies << @active1
        @farm1.vdi_desktop_pools << FactoryGirl.create(:vdi_desktop_pool, :name => 'MiqCitrix1', :vendor => 'citrix', :enabled => true, :ext_management_systems => [@zone1.ext_management_systems.first])

        @farm2 = FactoryGirl.create(:vdi_farm_citrix)
        @active2 = FactoryGirl.create(:active_cos_proxy)
        @active2.save
        @farm2.miq_proxies << @active2
        @farm2.vdi_desktop_pools << FactoryGirl.create(:vdi_desktop_pool, :name => 'MiqCitrix2', :vendor => 'citrix', :enabled => true, :ext_management_systems => [@zone2.ext_management_systems.first])
      end

      it "refresh_all_vdi_farms_timer in zone1 will refresh zone1 VdiFarm" do
        MiqServer.stub(:my_server).and_return(@zone1.miq_servers.first)

        VdiFarm.should_receive(:refresh_ems).with([@farm1.id])
        VdiFarm.refresh_all_vdi_farms_timer
      end

      it "refresh_all_vdi_farms_timer in zone2 will refresh zone2 VdiFarm" do
        MiqServer.stub(:my_server).and_return(@zone2.miq_servers.first)

        VdiFarm.should_receive(:refresh_ems).with([@farm2.id])
        VdiFarm.refresh_all_vdi_farms_timer
      end

    end

    context "a XenDesktop v4 Farm with a small vdi env" do
      before(:each) do
        @farm1 = FactoryGirl.create(:vdi_farm_citrix)
        @farm1.vdi_controllers << FactoryGirl.create(:vdi_controller, :name => 'CITRIX1')
        desktop_pools = FactoryGirl.create(:vdi_desktop_pool, :name => 'MiqCitrix', :vendor => 'citrix', :enabled => true, :uid_ems => 'b4ae34df-8c34-47f2-9576-ce6add1f5c82')
        desktop_pools.ext_management_systems << ExtManagementSystem.first
        desktop_pools.vdi_desktops << FactoryGirl.create(:vdi_desktop, :name => 'GALAXY\WINXP-VDI6$')
        @farm1.vdi_desktop_pools << desktop_pools

        @vm_uid_ems = desktop_pools.ext_management_systems.first.vms.first.uid_ems
        @data_dir = File.join(File.dirname(__FILE__), 'vdi_data/XenDesktop/v4')
      end

      it "when processing a 'VDI logon' event should create a ems_event" do
        ps_xml_data = File.read(File.join(@data_dir, 'VdiLoginSessionEvent.xml'))
        event_hash = MiqPowerShell::Convert.new(ps_xml_data).to_h.first
        event_hash[:vm_uid_ems] = @vm_uid_ems

        @farm1.add_event(:ps_event => event_hash)
        event = EmsEvent.first
        event.should_not be_nil
        event.event_type.should == 'VdiLoginSessionEvent'

        session = VdiSession.first
        session.state.should == 'Connected'
        session.vdi_endpoint_device_name.should_not be_blank

        # Check that VdiUser and VdiEndpointDevice were created
        VdiUser.count.should == 1
        VdiEndpointDevice.count.should == 1

        epd = VdiEndpointDevice.first
        epd.name.should_not be_blank
        epd.ipaddress.should_not be_blank
        epd.uid_ems.should_not be_blank

        ps_xml_data = File.read(File.join(@data_dir, 'VdiDisconnectedSessionEvent.xml'))
        event_hash = MiqPowerShell::Convert.new(ps_xml_data).to_h.first
        event_hash[:vm_uid_ems] = @vm_uid_ems
        @farm1.add_event(:ps_event => event_hash)
        session.reload
        session.state.should == 'Disconnected'

        # Logoff session should delete the Session object
        ps_xml_data = File.read(File.join(@data_dir, 'VdiLogoffSessionEvent.xml'))
        event_hash = MiqPowerShell::Convert.new(ps_xml_data).to_h.first
        event_hash[:vm_uid_ems] = @vm_uid_ems
        @farm1.add_event(:ps_event => event_hash)
        VdiSession.first.should be_nil
      end

      it "when processing a 'VDI Connecting' event should create a ems_event and vdi_session but not a vdi_endpoint_device" do
        # Connecting session only contains user info, not endpoint device info
        ps_xml_data = File.read(File.join(@data_dir, 'VdiConnectingSessionEvent.xml'))
        event_hash = MiqPowerShell::Convert.new(ps_xml_data).to_h.first
        event_hash[:vm_uid_ems] = @vm_uid_ems

        @farm1.add_event({:ps_event => event_hash})
        EmsEvent.count.should == 1
        VdiEndpointDevice.count.should == 0
        VdiUser.count.should  == 1
      end

      it "when processing a 'VDI Connecting' event should create a ems_event but not a vdi_user if UserSid property is missing" do
        ps_xml_data = File.read(File.join(@data_dir, 'VdiConnectingSessionEvent.xml'))
        event_hash = MiqPowerShell::Convert.new(ps_xml_data).to_h.first
        event_hash[:vm_uid_ems] = @vm_uid_ems
        event_hash[:session][:MS][:UserSid] = nil

        @farm1.add_event(:ps_event => event_hash)
        EmsEvent.count.should == 1
        VdiUser.count.should == 0
      end

      context "with a vdi_session" do
        before(:each) do
          @desktop = @farm1.vdi_desktops.first
          @desktop.vdi_sessions << FactoryGirl.create(:vdi_session, :state => "Connected")
        end

        it "return connection_state if available" do
          @desktop.connection_state = "Disconnected"
          @desktop.connection_state.should == "Disconnected"
        end

        it "use session object as fall-back connection_state" do
          @desktop.connection_state.should == "Connected"
        end

        it "return single connection_state value based on Alphabetical order" do
          @desktop.vdi_sessions << FactoryGirl.create(:vdi_session, :state => "Active")
          @desktop.connection_state.should == "Active"
        end
      end

      context "with a vm_vdi" do
        before(:each) do
          @desktop = @farm1.vdi_desktops.first
          @desktop.vm_vdi = Vm.first
          @desktop.vm_vdi.raw_power_state = "poweredOff"
        end

        it "return power_state if available" do
          @desktop.power_state = "On"
          @desktop.power_state.should == "On"
        end

        it "use vm_vdi object as fall-back power_state" do
          @desktop.power_state.should == "off"
        end
      end
    end

    context "a XenDesktop v5.6 Farm with a small vdi env" do
      before(:each) do
        @farm1 = FactoryGirl.create(:vdi_farm_citrix)
        @farm1.vdi_controllers << FactoryGirl.create(:vdi_controller, :name => 'Citrix-XD56-001.manageiq.com')
        desktop_pools = FactoryGirl.create(:vdi_desktop_pool, :name => 'XD56', :vendor => 'citrix', :enabled => true, :uid_ems => '23e09294-4b0c-4af1-afa7-69d2e92e36ac')
        desktop_pools.ext_management_systems << ExtManagementSystem.first
        desktop_pools.vdi_desktops << FactoryGirl.create(:vdi_desktop, :name => 'XD56-002')
        @farm1.vdi_desktop_pools << desktop_pools

        @vm_uid_ems = desktop_pools.ext_management_systems.first.vms.first.uid_ems
        @data_dir = File.join(File.dirname(__FILE__), 'vdi_data/XenDesktop/v5.6')
      end

      it "when processing a 'VDI logon' event should create a ems_event" do
        VdiUser.count.should == 0
        VdiEndpointDevice.count.should == 0

        ps_xml_data = File.read(File.join(@data_dir, 'A4 Login_active_with_user.xml'))
        event_hash = MiqPowerShell::Convert.new(ps_xml_data).to_h.first
        event_hash[:vm_uid_ems] = @vm_uid_ems

        @farm1.add_event(:ps_event => event_hash)
        event = EmsEvent.first
        event.should_not be_nil
        event.event_type.should == 'VdiLoginSessionEvent'

        session = VdiSession.first
        session.state.should == 'Active'

        # Check that VdiUser and VdiEndpointDevice were created
        VdiUser.count.should == 1
        VdiEndpointDevice.count.should == 1

        epd = VdiEndpointDevice.first
        epd.name.should_not be_blank
        epd.ipaddress.should_not be_blank
        epd.uid_ems.should_not be_blank

        ps_xml_data = File.read(File.join(@data_dir, 'A5 Disconnected.xml'))
        event_hash = MiqPowerShell::Convert.new(ps_xml_data).to_h.first
        event_hash[:vm_uid_ems] = @vm_uid_ems
        @farm1.add_event(:ps_event => event_hash)
        session.reload
        session.state.should == 'Disconnected'

        # Logoff session should delete the Session object
        ps_xml_data = File.read(File.join(@data_dir, 'A8 Logoff.xml'))
        event_hash = MiqPowerShell::Convert.new(ps_xml_data).to_h.first
        event_hash[:vm_uid_ems] = @vm_uid_ems
        @farm1.add_event(:ps_event => event_hash)
        VdiSession.first.should be_nil
      end

      it "when processing a 'VDI Connecting' event should create a ems_event and vdi_session but not a vdi_endpoint_device" do
        # Connecting session only contains user info, not endpoint device info
        ps_xml_data = File.read(File.join(@data_dir, 'A1 Connecting_preparing_session_no_controller.xml'))
        event_hash = MiqPowerShell::Convert.new(ps_xml_data).to_h.first
        event_hash[:vm_uid_ems] = @vm_uid_ems

        @farm1.add_event({:ps_event => event_hash})
        EmsEvent.count.should == 1
        VdiEndpointDevice.count.should == 0
        VdiUser.count.should  == 1
      end

      it "when processing a 'VDI Connecting' event should create a ems_event but not a vdi_user if UserSid property is missing" do
        ps_xml_data = File.read(File.join(@data_dir, 'A1 Connecting_preparing_session_no_controller.xml'))
        event_hash = MiqPowerShell::Convert.new(ps_xml_data).to_h.first
        event_hash[:vm_uid_ems] = @vm_uid_ems
        event_hash[:session][:MS][:UserSid] = nil
        event_hash[:session][:MS][:BrokeringUserName] = nil

        @farm1.add_event(:ps_event => event_hash)
        EmsEvent.count.should == 1
        VdiUser.count.should == 0
      end
    end

    # context "with a non-brokered session" do
    #   #debugger
    # end

  end
end
