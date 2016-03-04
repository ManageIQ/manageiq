require "spec_helper"

describe ManageIQ::Providers::Oracle::InfraManager do
  it ".ems_type" do
    described_class.ems_type.should == 'oraclevm'
  end

  it ".description" do
    described_class.description.should == 'Oracle Virtualization Manager'
  end
end
