require 'spec_helper'

describe "Available_Resource_Groups Method Validation" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:default_value) { "<New resource group>" }
  before do
    @ins = "/Cloud/Orchestration/Operations/Methods/Available_Resource_Groups"
  end

  context "workspace has no service template" do
    it "provides only default value to the resource group list" do
      ws = MiqAeEngine.instantiate("#{@ins}", user)
      ws.root["values"].should == {nil => default_value}
    end
  end

  context "workspace has service template other than orchestration" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it "provides only default value to the resource group list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      ws.root["values"].should == {nil => default_value}
    end
  end

  context "workspace has orchestration service template" do
    let(:ems) do
      @rgroup1 = FactoryGirl.create(:resource_group)
      @rgroup2 = FactoryGirl.create(:resource_group)
      FactoryGirl.create(:ems_azure, :resource_groups => [@rgroup1, @rgroup2])
    end

    let(:service_template) do
      FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
    end

    let(:service_template_no_ems) do
      FactoryGirl.create(:service_template_orchestration)
    end

    it "finds all the resource groups and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}", user)
      ws.root["values"].should include(
        nil           => default_value,
        @rgroup1.name => @rgroup1.name,
        @rgroup2.name => @rgroup2.name
      )
    end

    it "provides only default value to the resource group list if orchestration manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_no_ems.id}", user)
      ws.root["values"].should == {nil => default_value}
    end
  end
end
