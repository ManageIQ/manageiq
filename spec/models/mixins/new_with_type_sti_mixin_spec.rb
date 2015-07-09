require "spec_helper"

describe NewWithTypeStiMixin do
  context ".new" do
    it "without type" do
      Host.new.class.should          == Host
      ManageIQ::Providers::Redhat::InfraManager::Host.new.class.should    == ManageIQ::Providers::Redhat::InfraManager::Host
      ManageIQ::Providers::Vmware::InfraManager::Host.new.class.should    == ManageIQ::Providers::Vmware::InfraManager::Host
      ManageIQ::Providers::Vmware::InfraManager::HostEsx.new.class.should == ManageIQ::Providers::Vmware::InfraManager::HostEsx
    end

    it "with type" do
      Host.new(:type => "Host").class.should          == Host
      Host.new(:type => "ManageIQ::Providers::Redhat::InfraManager::Host").class.should    == ManageIQ::Providers::Redhat::InfraManager::Host
      Host.new(:type => "ManageIQ::Providers::Vmware::InfraManager::Host").class.should    == ManageIQ::Providers::Vmware::InfraManager::Host
      Host.new(:type => "ManageIQ::Providers::Vmware::InfraManager::HostEsx").class.should == ManageIQ::Providers::Vmware::InfraManager::HostEsx
      ManageIQ::Providers::Vmware::InfraManager::Host.new(:type  => "ManageIQ::Providers::Vmware::InfraManager::HostEsx").class.should == ManageIQ::Providers::Vmware::InfraManager::HostEsx

      Host.new("type" => "Host").class.should          == Host
      Host.new("type" => "ManageIQ::Providers::Redhat::InfraManager::Host").class.should    == ManageIQ::Providers::Redhat::InfraManager::Host
      Host.new("type" => "ManageIQ::Providers::Vmware::InfraManager::Host").class.should    == ManageIQ::Providers::Vmware::InfraManager::Host
      Host.new("type" => "ManageIQ::Providers::Vmware::InfraManager::HostEsx").class.should == ManageIQ::Providers::Vmware::InfraManager::HostEsx
      ManageIQ::Providers::Vmware::InfraManager::Host.new("type" => "ManageIQ::Providers::Vmware::InfraManager::HostEsx").class.should == ManageIQ::Providers::Vmware::InfraManager::HostEsx
    end

    context "with invalid type" do
      it "that doesn't exist" do
        lambda { Host.new(:type  => "Xxx") }.should raise_error
        lambda { Host.new("type" => "Xxx") }.should raise_error
      end

      it "that isn't a subclass" do
        lambda { Host.new(:type  => "ManageIQ::Providers::Vmware::InfraManager::Vm") }.should raise_error
        lambda { Host.new("type" => "ManageIQ::Providers::Vmware::InfraManager::Vm") }.should raise_error

        lambda { ManageIQ::Providers::Vmware::InfraManager::Host.new(:type  => "Host") }.should raise_error
        lambda { ManageIQ::Providers::Vmware::InfraManager::Host.new("type" => "Host") }.should raise_error

        lambda { ManageIQ::Providers::Vmware::InfraManager::Host.new(:type  => "ManageIQ::Providers::Redhat::InfraManager::Host") }.should raise_error
        lambda { ManageIQ::Providers::Vmware::InfraManager::Host.new("type" => "ManageIQ::Providers::Redhat::InfraManager::Host") }.should raise_error
      end
    end
  end
end
