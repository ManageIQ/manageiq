require "spec_helper"

describe ManageIQ::Providers::Openstack::CloudManager do
  context "Class Methods" do
    it("from mixin") { expect(described_class.methods).to include(:auth_url, :raw_connect) }
  end

  it ".ems_type" do
    described_class.ems_type.should == 'openstack'
  end

  it ".description" do
    described_class.description.should == 'OpenStack'
  end

  context "validation" do
    before :each do
      @ems = FactoryGirl.create(:ems_openstack_with_authentication)
      require 'openstack/openstack_event_monitor'
    end

    it "verifies AMQP credentials" do
      EvmSpecHelper.stub_amqp_support

      creds = {}
      creds[:amqp] = {:userid => "amqp_user", :password => "amqp_password"}
      @ems.update_authentication(creds, { :save => false })
      @ems.verify_credentials(:amqp).should be_true
    end

    it "indicates that an event monitor is available" do
      OpenstackEventMonitor.stub(:available?).and_return(true)
      @ems.event_monitor_available?.should be_true
    end

    it "indicates that an event monitor is not available" do
      OpenstackEventMonitor.stub(:available?).and_return(false)
      @ems.event_monitor_available?.should be_false
    end

    it "logs an error and indicates that an event monitor is not available when there's an error checking for an event monitor" do
      OpenstackEventMonitor.stub(:available?).and_raise(StandardError)
      $log.should_receive(:error).with(/Exeption trying to find openstack event monitor/)
      @ems.event_monitor_available?.should be_false
    end
  end

  it "event_monitor_options" do
    ManageIQ::Providers::Openstack::CloudManager::EventCatcher.stub(:worker_settings => {:amqp_port => 1234})
    @ems = FactoryGirl.build(:ems_openstack, :hostname => "host", :ipaddress => "::1")
    require 'openstack/openstack_event_monitor'

    @ems.event_monitor_options.should == {:hostname => "host", :port => 1234}
  end

  context "translate_exception" do
    it "preserves and logs message for unknown exceptions" do
      ems = FactoryGirl.build(:ems_openstack, :hostname => "host", :ipaddress => "::1")

      creds = {:default => {:userid => "fake_user", :password => "fake_password"}}
      ems.update_authentication(creds, :save => false)

      ems.stub(:with_provider_connection).and_raise(StandardError, "unlikely")

      $log.should_receive(:error).with(/unlikely/)
      expect { ems.verify_credentials }.to raise_error(MiqException::MiqEVMLoginError, /Unexpected.*unlikely/)
    end
  end
end
