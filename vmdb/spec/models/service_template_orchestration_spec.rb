require "spec_helper"

describe ServiceTemplateOrchestration do
  let(:service_template) { FactoryGirl.create(:service_template_orchestration) }

  context "#orchestration_template" do
    let(:first_orch_template) { FactoryGirl.create(:orchestration_template) }
    let(:second_orch_template) { FactoryGirl.create(:orchestration_template) }

    it "initially reads a nil orchestration template" do
      service_template.orchestration_template.should be_nil
    end

    it "adds an orchestration template" do
      service_template.orchestration_template = first_orch_template
      service_template.orchestration_template.should == first_orch_template
    end

    it "replaces the existing orchestration template" do
      service_template.orchestration_template = first_orch_template
      service_template.orchestration_template = second_orch_template

      service_template.orchestration_template.should == second_orch_template
      service_template.orchestration_template.should_not == first_orch_template
    end

    it "clears the existing orchestration template" do
      service_template.orchestration_template = first_orch_template
      service_template.orchestration_template = nil

      service_template.orchestration_template.should be_nil
    end
  end

  context "#orchestration_manager" do
    let(:ems_amazon) { FactoryGirl.create(:ems_amazon) }
    let(:ems_openstack) { FactoryGirl.create(:ems_openstack) }

    it "initially reads a nil orchestration manager" do
      service_template.orchestration_manager.should be_nil
    end

    it "adds an orchestration manager" do
      service_template.orchestration_manager = ems_openstack
      service_template.orchestration_manager.should == ems_openstack
    end

    it "replaces the existing orchestration manager" do
      service_template.orchestration_manager = ems_openstack
      service_template.orchestration_manager = ems_amazon

      service_template.orchestration_manager.should == ems_amazon
      service_template.orchestration_manager.should_not == ems_openstack
    end

    it "clears the existing orchestration manager" do
      service_template.orchestration_manager = ems_openstack
      service_template.orchestration_manager = nil

      service_template.orchestration_manager.should be_nil
    end
  end
end
