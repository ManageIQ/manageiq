require "spec_helper"
require 'ovirt'
require 'ovirt_metrics'


describe ManageIQ::Providers::Redhat::InfraManager do
  it ".ems_type" do
    described_class.ems_type.should == 'rhevm'
  end

  it ".description" do
    described_class.description.should == 'Red Hat Enterprise Virtualization Manager'
  end

  it "rhevm_metrics_connect_options" do
    h = FactoryGirl.create(:ems_redhat, :hostname => "h")
    h.rhevm_metrics_connect_options[:host].should == "h"
  end

  it "rhevm_metrics_connect_options overrides" do
    h = FactoryGirl.create(:ems_redhat, :hostname => "h")
    h.rhevm_metrics_connect_options(:hostname => "i")[:host].should == "i"
  end

  it "connect Metrics" do
    h = FactoryGirl.create(:ems_redhat, :hostname => "h")
    expect(OvirtMetrics).to receive(:connect).and_return(:token)
    expect(h.connect(:service => "Metrics")).to eq(:token)
  end

  it "connect Inventory" do
    h = FactoryGirl.create(:ems_redhat, :hostname => "h")
    expect(h).to receive(:other_connect)
    h.connect(:service => "Inventory")
  end

  it "connect" do
    h = FactoryGirl.create(:ems_redhat, :hostname => "h")
    expect(h).to receive(:other_connect)
    h.connect()
  end
end
