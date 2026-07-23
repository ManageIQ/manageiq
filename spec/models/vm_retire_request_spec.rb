RSpec.describe VmRetireRequest do
  let!(:ems) { FactoryBot.create(:ems_vmware) }
  let!(:vm) { FactoryBot.create(:vm_vmware, :ext_management_system => ems) }

  describe ".request_task_class_from" do
    context "with custom EMS retire task class" do
      let(:custom_task_class) { Class.new(VmRetireTask) }

      before do
        stub_const("ManageIQ::Providers::Vmware::InfraManager::VmRetireTask", custom_task_class)
        allow(ems.class).to receive(:vm_retire_task_class).and_return(custom_task_class)
      end

      it "returns the custom task class" do
        attribs = {'options' => {:src_ids => [vm.id]}}
        expect(described_class.request_task_class_from(attribs)).to eq(custom_task_class)
      end
    end

    context "with VMware EMS (has built-in custom retire task class)" do
      it "returns ManageIQ::Providers::Vmware::InfraManager::Retire" do
        attribs = {'options' => {:src_ids => [vm.id]}}
        expect(described_class.request_task_class_from(attribs)).to eq(ManageIQ::Providers::Vmware::InfraManager::Retire)
      end
    end

    context "with VM that has no EMS" do
      let!(:vm_no_ems) { FactoryBot.create(:vm_vmware, :ext_management_system => nil) }

      it "returns VmRetireTask" do
        attribs = {'options' => {:src_ids => [vm_no_ems.id]}}
        expect(described_class.request_task_class_from(attribs)).to eq(VmRetireTask)
      end
    end

    context "with src_ids option" do
      it "handles src_ids option" do
        attribs = {'options' => {:src_ids => [vm.id]}}
        expect { described_class.request_task_class_from(attribs) }.not_to raise_error
        expect(described_class.request_task_class_from(attribs)).to eq(ManageIQ::Providers::Vmware::InfraManager::Retire)
      end
    end

    context "when VM is not found" do
      it "raises MiqRetireRequestError" do
        attribs = {'options' => {:src_ids => [-1]}}
        expect { described_class.request_task_class_from(attribs) }
          .to raise_error(MiqException::MiqRetireRequestError, /Unable to find Vm/)
      end
    end
  end

  describe ".new_request_task" do
    it "creates a task with the correct class" do
      attribs = {
        'options'     => {:src_ids => [vm.id]},
        'source_id'   => vm.id,
        'source_type' => 'Vm'
      }

      task = described_class.new_request_task(attribs)
      expect(task).to be_a(VmRetireTask)
      expect(task.source_id).to eq(vm.id)
    end

    context "with custom EMS retire task class" do
      let(:custom_task_class) { Class.new(VmRetireTask) }

      before do
        stub_const("ManageIQ::Providers::Vmware::InfraManager::VmRetireTask", custom_task_class)
        allow(ems.class).to receive(:vm_retire_task_class).and_return(custom_task_class)
      end

      it "creates a task with the custom class" do
        attribs = {
          'options'     => {:src_ids => [vm.id]},
          'source_id'   => vm.id,
          'source_type' => 'Vm'
        }

        task = described_class.new_request_task(attribs)
        expect(task).to be_a(custom_task_class)
        expect(task.source_id).to eq(vm.id)
      end
    end
  end
end
