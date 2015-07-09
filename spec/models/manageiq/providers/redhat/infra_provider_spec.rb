require "spec_helper"

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
end
