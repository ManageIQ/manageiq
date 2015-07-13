require "spec_helper"

describe MiqEnterprise do
  before(:each) { @ent = FactoryGirl.create(:miq_enterprise) }

  context "with all existing records" do
    it "#miq_regions" do
      MiqRegion.seed

      expect(@ent.miq_regions.size).to eq(1)
    end

    it "#ext_management_systems" do
      ems = [FactoryGirl.create(:ems_vmware), FactoryGirl.create(:ems_vmware)]

      expect(@ent.ext_management_systems).to match_array(ems)
    end

    it "#storages" do
      storage = FactoryGirl.create(:storage)

      expect(@ent.storages).to eq([storage])
    end

    it "#policy_events" do
      policy_events = [FactoryGirl.create(:policy_event), FactoryGirl.create(:policy_event)]

      expect(@ent.policy_events).to match_array(policy_events)
    end
  end

  context "with some existing records" do
    before(:each) do
      @ems  = FactoryGirl.create(:ems_vmware)
    end

    it "#vms_and_templates" do
      vm_1 = FactoryGirl.create(:vm_vmware, :ext_management_system => @ems)
      FactoryGirl.create(:vm_vmware)

      template_1 = FactoryGirl.create(:template_vmware, :ext_management_system => @ems)
      FactoryGirl.create(:template_vmware)

      expect(@ent.vms_and_templates).to match_array([vm_1, template_1])
    end

    it "#vms" do
      vm   = [FactoryGirl.create(:vm_vmware, :ext_management_system => @ems),
              FactoryGirl.create(:vm_vmware, :ext_management_system => @ems)]

      FactoryGirl.create(:vm_vmware)

      expect(@ent.vms).to match_array(vm)
    end

    it "#miq_templates" do
      template = FactoryGirl.create(:template_redhat, :ext_management_system => @ems)

      FactoryGirl.create(:template_redhat)

      expect(@ent.miq_templates).to eq([template])
    end

    it "#hosts" do
      hosts = [ FactoryGirl.create(:host_vmware, :ext_management_system => @ems),
                FactoryGirl.create(:host_vmware, :ext_management_system => @ems)]

      FactoryGirl.create(:host_vmware)

      expect(@ent.hosts).to match_array(hosts)
    end
  end

end
