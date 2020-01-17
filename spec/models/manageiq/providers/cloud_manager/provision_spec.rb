RSpec.describe ManageIQ::Providers::CloudManager::Provision do
  context "Cloning" do
    let(:provider) { FactoryBot.create(:ems_cloud) }
    let(:template) { FactoryBot.create(:template_cloud, :ext_management_system => provider) }
    let(:vm) { FactoryBot.create(:vm_cloud, :ext_management_system => provider, :ems_ref => "vm_1") }

    before do
      subject.source = template
    end

    describe "#find_destination_in_vmdb" do
      it "finds a VM" do
        expect(subject.find_destination_in_vmdb(vm.ems_ref)).to eq(vm)
      end
    end

    describe "#validate_dest_name" do
      it "passes with valid name" do
        allow(subject).to receive(:dest_name).and_return("new_vm_1")
        expect { subject.validate_dest_name }.to_not raise_error
      end

      it "raises an error with a blank name" do
        allow(subject).to receive(:dest_name).and_return("")
        expect { subject.validate_dest_name }
          .to raise_error(MiqException::MiqProvisionError, /Destination Name cannot be blank/)
      end

      it "raises an error with a nil name" do
        allow(subject).to receive(:dest_name).and_return(nil)
        expect { subject.validate_dest_name }
          .to raise_error(MiqException::MiqProvisionError, /Destination Name cannot be blank/)
      end

      it "raises an error with a duplicate name" do
        allow(subject).to receive(:dest_name).and_return(vm.name)
        expect { subject.validate_dest_name }.to raise_error(MiqException::MiqProvisionError, /already exists/)
      end
    end
  end
end
