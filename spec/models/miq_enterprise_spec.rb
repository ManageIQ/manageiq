RSpec.describe MiqEnterprise do
  subject { enterprise }

  include_examples "MiqPolicyMixin"
  include_examples ".seed called multiple times", 1

  # TODO:  Make this `subject` for consistency
  let(:enterprise) { FactoryBot.create(:miq_enterprise) }

  context "with all existing records" do
    it "#miq_regions" do
      MiqRegion.seed

      expect(enterprise.miq_regions.size).to eq(1)
    end

    it "#ext_management_systems" do
      ems = [FactoryBot.create(:ems_vmware), FactoryBot.create(:ems_vmware)]

      expect(enterprise.ext_management_systems).to match_array(ems)
    end

    it "#storages" do
      storage = FactoryBot.create(:storage)

      expect(enterprise.storages).to eq([storage])
    end

    it "#policy_events" do
      policy_events = [FactoryBot.create(:policy_event), FactoryBot.create(:policy_event)]

      expect(enterprise.policy_events).to match_array(policy_events)
    end
  end

  context "with some existing records" do
    before do
      @ems  = FactoryBot.create(:ems_vmware)
    end

    it "#vms_and_templates" do
      vm_1 = FactoryBot.create(:vm_vmware, :ext_management_system => @ems)
      FactoryBot.create(:vm_vmware)

      template_1 = FactoryBot.create(:template_vmware, :ext_management_system => @ems)
      FactoryBot.create(:template_vmware)

      expect(enterprise.vms_and_templates).to match_array([vm_1, template_1])
    end

    it "#vms" do
      vm   = [FactoryBot.create(:vm_vmware, :ext_management_system => @ems),
              FactoryBot.create(:vm_vmware, :ext_management_system => @ems)]

      FactoryBot.create(:vm_vmware)

      expect(enterprise.vms).to match_array(vm)
    end

    it "#miq_templates" do
      template = FactoryBot.create(:template_redhat, :ext_management_system => @ems)

      FactoryBot.create(:template_redhat)

      expect(enterprise.miq_templates).to eq([template])
    end

    it "#hosts" do
      hosts = [FactoryBot.create(:host_vmware, :ext_management_system => @ems),
               FactoryBot.create(:host_vmware, :ext_management_system => @ems)]

      FactoryBot.create(:host_vmware)

      expect(enterprise.hosts).to match_array(hosts)
    end
  end
end
