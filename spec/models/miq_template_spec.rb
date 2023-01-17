RSpec.describe MiqTemplate do
  include Spec::Support::SupportsHelper

  subject { FactoryBot.create(:template) }

  include_examples "ComplianceMixin"

  it ".corresponding_model" do
    expect(described_class.corresponding_model).to eq(Vm)
    expect(ManageIQ::Providers::Vmware::InfraManager::Template.corresponding_model).to eq(ManageIQ::Providers::Vmware::InfraManager::Vm)
    expect(ManageIQ::Providers::Redhat::InfraManager::Template.corresponding_model).to eq(ManageIQ::Providers::Redhat::InfraManager::Vm)
  end

  it ".corresponding_vm_model" do
    expect(described_class.corresponding_vm_model).to eq(Vm)
    expect(ManageIQ::Providers::Vmware::InfraManager::Template.corresponding_vm_model).to eq(ManageIQ::Providers::Vmware::InfraManager::Vm)
    expect(ManageIQ::Providers::Redhat::InfraManager::Template.corresponding_vm_model).to eq(ManageIQ::Providers::Redhat::InfraManager::Vm)
  end

  context "#template=" do
    let(:template) { FactoryBot.create(:template_vmware) }

    it "true" do
      template.update_attribute(:template, true)
      expect(template.type).to eq("ManageIQ::Providers::Vmware::InfraManager::Template")
      expect(template.template).to eq(true)
      expect(template.state).to eq("never")
      expect { template.reload }.not_to raise_error
      expect { ManageIQ::Providers::Vmware::InfraManager::Vm.find(template.id) }.to raise_error ActiveRecord::RecordNotFound
    end

    it "false" do
      template.update_attribute(:template, false)
      expect(template.type).to eq("ManageIQ::Providers::Vmware::InfraManager::Vm")
      expect(template.template).to eq(false)
      expect(template.state).to eq("unknown")
      expect { template.reload }.to raise_error ActiveRecord::RecordNotFound
      expect { ManageIQ::Providers::Vmware::InfraManager::Vm.find(template.id) }.not_to raise_error
    end
  end

  it ".supports?(:kickstart_provisioning)" do
    expect(ManageIQ::Providers::Amazon::CloudManager::Template.supports?(:kickstart_provisioning)).to be_falsey
    expect(ManageIQ::Providers::Redhat::InfraManager::Template.supports?(:kickstart_provisioning)).to be_truthy
    expect(ManageIQ::Providers::Vmware::InfraManager::Template.supports?(:kickstart_provisioning)).to be_falsey
  end

  it "#supports?(:kickstart_provisioning)" do
    expect(ManageIQ::Providers::Amazon::CloudManager::Template.new.supports?(:kickstart_provisioning)).to be_falsey
    expect(ManageIQ::Providers::Redhat::InfraManager::Template.new.supports?(:kickstart_provisioning)).to be_truthy
    expect(ManageIQ::Providers::Vmware::InfraManager::Template.new.supports?(:kickstart_provisioning)).to be_falsey
  end

  it "#supports?(:provisioning)" do
    template = FactoryBot.create(:template_openstack)
    FactoryBot.create(:ems_openstack, :miq_templates => [template])
    expect(template.supports?(:provisioning)).to be_truthy

    template = FactoryBot.create(:template_openstack)
    expect(template.supports?(:provisioning)).to be_falsey

    template = FactoryBot.create(:template_openstack)
    FactoryBot.create(:ems_openstack, :miq_templates => [template])
    expect(template.supports?(:provisioning)).to be_truthy
  end

  describe ".eligible_for_provisioning" do
    context "with no templates" do
      it "returns an empty set" do
        expect(described_class.eligible_for_provisioning).to be_empty
      end
    end

    context "with a template" do
      let!(:template) { FactoryBot.create(:template_infra, :ext_management_system => ems) }
      let(:ems)       { nil }

      context "that does not support provisioning" do
        it "returns an empty set" do
          expect(described_class.eligible_for_provisioning).to be_empty
        end
      end

      context "that supports provisioning" do
        before { stub_supports(template, :provisioning) }

        context "not connected to an EMS" do
          it "returns an empty set" do
            expect(described_class.eligible_for_provisioning).to be_empty
          end
        end

        context "connected to an EMS" do
          let(:ems) { FactoryBot.create(:ems_infra) }

          it "returns the template" do
            expect(described_class.eligible_for_provisioning).to include(template)
          end
        end
      end
    end
  end
end
