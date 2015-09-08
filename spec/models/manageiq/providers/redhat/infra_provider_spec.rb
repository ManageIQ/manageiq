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

  context '#rhevm_metrics_connect_options' do
    it "rhevm_metrics_connect_options" do
      h = FactoryGirl.create(:ems_redhat, :hostname => "h")
      h.rhevm_metrics_connect_options[:host].should == "h"
    end

    it "rhevm_metrics_connect_options overrides" do
      h = FactoryGirl.create(:ems_redhat, :hostname => "h")
      h.rhevm_metrics_connect_options(:hostname => "i")[:host].should == "i"
    end
  end

  context '#connect' do
    before do
      described_class.any_instance.stub(:missing_credentials? => false)
    end

    it "connect Metrics" do
      h = FactoryGirl.create(:ems_redhat)
      expect(OvirtMetrics).to receive(:connect).and_return(:token)
      expect(h.connect(:service => "Metrics")).to eq(:token)
    end

    it "connect Inventory" do
      h = FactoryGirl.create(:ems_redhat)
      expect(Ovirt::Inventory).to receive(:new).and_return(:token)
      expect(h.connect(:service => "Inventory")).to eq(:token)
    end

    it "connect default" do
      h = FactoryGirl.create(:ems_redhat)
      expect(Ovirt::Service).to receive(:new).and_return(:token)
      expect(h.connect).to eq(:token)
    end
  end
end
