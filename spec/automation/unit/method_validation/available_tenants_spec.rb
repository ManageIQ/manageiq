require 'spec_helper'

describe "Available_Tenants Method Validation" do
  before do
    @ins = "/Cloud/Orchestration/Operations/Methods/Available_Tenants"
  end

  context "workspace has no service template" do
    it "provides only default value to the tenant list" do
      ws = MiqAeEngine.instantiate("#{@ins}")
      ws.root["values"].should == {nil => "default"}
    end
  end

  context "workspece has service template other than orchestration" do
    let(:service_template) { FactoryGirl.create(:service_template) }

    it "provides only default value to the tenant list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}")
      ws.root["values"].should == {nil => "default"}
    end
  end

  context "workspece has orchestration service template" do
    let(:ems) do
      @tenant1 = FactoryGirl.create(:cloud_tenant)
      @tenant2 = FactoryGirl.create(:cloud_tenant)
      FactoryGirl.create(:ems_openstack, :cloud_tenants => [@tenant1, @tenant2])
    end

    let(:service_template) do
      FactoryGirl.create(:service_template_orchestration, :orchestration_manager => ems)
    end

    let(:service_template_no_ems) do
      FactoryGirl.create(:service_template_orchestration)
    end

    it "finds all the tenants and populates the list" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template.id}")
      ws.root["values"].should include(
        nil           => "default",
        @tenant1.name => @tenant1.name,
        @tenant2.name => @tenant2.name
      )
    end

    it "provides only default value to the tenant list if orchestration manager does not exist" do
      ws = MiqAeEngine.instantiate("#{@ins}?ServiceTemplate::service_template=#{service_template_no_ems.id}")
      ws.root["values"].should == {nil => "default"}
    end
  end
end
