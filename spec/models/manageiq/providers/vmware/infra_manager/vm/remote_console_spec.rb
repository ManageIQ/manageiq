require "spec_helper"

describe ManageIQ::Providers::Vmware::InfraManager::Vm::RemoteConsole do
  context "#remote_console_acquire_ticket" do
    before(:each) do
      @vm = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
    end

    it "with :mks" do
      @vm.should_receive(:remote_console_mks_acquire_ticket).with(nil)
      @vm.remote_console_acquire_ticket(:mks)
    end

    it "with :vmrc" do
      @vm.should_receive(:remote_console_vmrc_acquire_ticket).with(nil)
      @vm.remote_console_acquire_ticket(:vmrc)
    end

    context "with :vnc" do
      it "without a proxy" do
        @vm.should_receive(:remote_console_vnc_acquire_ticket).with(nil)
        @vm.remote_console_acquire_ticket(:vnc)
      end

      it "with a proxy" do
        server = double("MiqServer")
        @vm.should_receive(:remote_console_vnc_acquire_ticket).with(server)
        @vm.remote_console_acquire_ticket(:vnc, server)
      end
    end
  end

  context "#remote_console_acquire_ticket_queue" do
    before(:each) do
      @vm = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
      @vm.stub(:my_zone => nil)

      @server = double("MiqServer")
      @server.stub(:my_zone => nil)
      MiqServer.stub(:my_server => @server)
    end

    it "with :mks" do
      @vm.remote_console_acquire_ticket_queue(:mks, "admin")

      q_all = MiqQueue.all
      q_all.length.should == 1
      q_all[0].method_name.should == "remote_console_acquire_ticket"
      q_all[0].args.should == [:mks, nil]
    end

    it "with :vmrc" do
      @vm.remote_console_acquire_ticket_queue(:vmrc, "admin")

      q_all = MiqQueue.all
      q_all.length.should == 1
      q_all[0].method_name.should == "remote_console_acquire_ticket"
      q_all[0].args.should == [:vmrc, nil]
    end

    it "with :vnc" do
      @vm.remote_console_acquire_ticket_queue(:vnc, "admin", 1234)

      q_all = MiqQueue.all
      q_all.length.should == 1
      q_all[0].method_name.should == "remote_console_acquire_ticket"
      q_all[0].args.should == [:vnc, 1234]
    end
  end

  context "#remote_console_vmrc_acquire_ticket" do
    before(:each) do
      @ems = FactoryGirl.create(:ems_vmware, :hostname => "192.168.252.16", :ipaddress => "192.168.252.16", :api_version => "5.0", :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      @vm = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
    end

    it "normal case" do
      EvmSpecHelper.create_guid_miq_server_zone
      @ems.update_attributes(:ipaddress => "192.168.252.14", :hostname => "192.168.252.14")
      @ems.authentications = [FactoryGirl.create(:authentication, :userid => "dev1", :password => "dev1pass", :authtype => "default")]
      ticket = VCR.use_cassette(described_class.name.underscore) do
        @vm.remote_console_vmrc_acquire_ticket
      end
      ticket.should =~ /^[0-9\-A-Z]{40}$/
    end

    it "with vm off" do
      @vm.update_attribute(:raw_power_state, "poweredOff")
      -> { @vm.remote_console_vmrc_acquire_ticket }.should raise_error MiqException::RemoteConsoleNotSupportedError
    end

    it "with vm with no ems" do
      @vm.ext_management_system = nil
      @vm.save!
      -> { @vm.remote_console_vmrc_acquire_ticket }.should raise_error MiqException::RemoteConsoleNotSupportedError
    end
  end

  context "#validate_remote_console_vmrc_support" do
    before(:each) do
      @ems = FactoryGirl.create(:ems_vmware, :hostname => "192.168.252.16", :ipaddress => "192.168.252.16", :api_version => "5.0", :uid_ems => "2E1C1E82-BD83-4E54-9271-630C6DFAD4D1")
      @vm = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems)
    end

    it "normal case" do
      @vm.validate_remote_console_vmrc_support.should be_true
    end

    it "with vm with no ems" do
      @vm.ext_management_system = nil
      @vm.save!
      -> { @vm.validate_remote_console_vmrc_support }.should raise_error MiqException::RemoteConsoleNotSupportedError
    end

    it "with vm off" do
      @vm.update_attribute(:raw_power_state, "poweredOff")
      -> { @vm.validate_remote_console_vmrc_support }.should raise_error MiqException::RemoteConsoleNotSupportedError
    end

    it "on VC 4.0" do
      @ems.update_attribute(:api_version, "4.0")
      -> { @vm.validate_remote_console_vmrc_support }.should raise_error MiqException::RemoteConsoleNotSupportedError
    end
  end

  context "#remote_console_vnc_acquire_ticket" do
    before(:each) do
      @ems  = FactoryGirl.create(:ems_vmware)
      @host = FactoryGirl.create(:host_vmware, :ext_management_system => @ems, :hostname => "192.168.252.4", :ipaddress => "192.168.252.4", :next_available_vnc_port => 5901)
      @vm   = FactoryGirl.create(:vm_with_ref, :ext_management_system => @ems, :host => @host)
    end

    it "will set the attributes on the VC side" do
      vim_vm = double("MiqVimVm")
      vim_vm.should_receive(:setRemoteDisplayVncAttributes) do |args|
        args[:enabled].should  be_true
        args[:port].should == 5901
        args[:password].should =~ /^[A-Za-z0-9+\/]{8}$/
      end
      @vm.stub(:with_provider_object).and_yield(vim_vm)

      @vm.remote_console_vnc_acquire_ticket
    end

    it "without a proxy miq_server" do
      @vm.should_receive(:with_provider_object)

      password, host_address, host_port, proxy_address, proxy_port = @vm.remote_console_vnc_acquire_ticket

      password.should =~ /^[A-Za-z0-9+\/]{8}$/
      host_address.should == "192.168.252.4"
      host_port.should == 5901
      proxy_address.should be_nil
      proxy_port.should    be_nil
    end

    context "with a proxy miq_server" do
      it "with no proxy configured" do
        server = double("MiqServer")
        server.stub_chain(:get_config, :config => {:server => {:vnc_proxy_address => nil, :vnc_proxy_port => nil}})
        @vm.should_receive(:with_provider_object)

        password, host_address, host_port, proxy_address, proxy_port = @vm.remote_console_vnc_acquire_ticket(server)

        password.should =~ /^[A-Za-z0-9+\/]{8}$/
        host_address.should == "192.168.252.4"
        host_port.should == 5901
        proxy_address.should be_nil
        proxy_port.should    be_nil
      end

      it "with a proxy configured" do
        server = double("MiqServer")
        server.stub_chain(:get_config, :config => {:server => {:vnc_proxy_address => "1.2.3.4", :vnc_proxy_port => "5800"}}) # NOTE: Ports are actually stored as a String in the configuration
        @vm.should_receive(:with_provider_object)

        password, host_address, host_port, proxy_address, proxy_port = @vm.remote_console_vnc_acquire_ticket(server)

        password.should =~ /^[A-Za-z0-9+\/]{8}$/
        host_address.should == @host.guid
        host_port.should == 5901
        proxy_address.should == "1.2.3.4"
        proxy_port.should == 5800
      end
    end

    it "will reclaim the port number from old VMs" do
      ManageIQ::Providers::Vmware::InfraManager::Vm.any_instance.stub(:with_provider_object)
      vm_old = FactoryGirl.create(:vm_with_ref, :host => @host, :vnc_port => 5901)

      @vm.remote_console_vnc_acquire_ticket

      vm_old.reload
      vm_old.vnc_port.should be_nil
    end
  end
end
