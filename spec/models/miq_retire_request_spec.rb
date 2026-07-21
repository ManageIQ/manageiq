RSpec.describe MiqRetireRequest do
  let!(:ems)     { FactoryBot.create(:ems_vmware) }
  let!(:vm)      { FactoryBot.create(:vm_vmware, :ext_management_system => ems) }
  let!(:service) { FactoryBot.create(:service) }

  describe ".request_task_class_from" do
    context "when source has no EMS" do
      let(:request_class) { ServiceRetireRequest }

      it "returns the default task class" do
        attribs = {'options' => {:src_ids => [service.id]}}
        expect(request_class.request_task_class_from(attribs)).to eq(ServiceRetireTask)
      end
    end

    context "when source has EMS with custom task class" do
      let(:request_class) { VmRetireRequest }

      it "returns the custom task class from the EMS" do
        attribs = {'options' => {:src_ids => [vm.id]}}
        expect(request_class.request_task_class_from(attribs)).to eq(ManageIQ::Providers::Vmware::InfraManager::Retire)
      end
    end

    context "when source is not found" do
      let(:request_class) { VmRetireRequest }

      it "raises MiqRetireRequestError" do
        attribs = {'options' => {:src_ids => [-1]}}
        expect { request_class.request_task_class_from(attribs) }
          .to raise_error(MiqException::MiqRetireRequestError, /Unable to find Vm/)
      end
    end

    context "with src_ids option" do
      let(:request_class) { VmRetireRequest }

      it "handles src_ids option" do
        attribs = {'options' => {:src_ids => [vm.id]}}
        expect { request_class.request_task_class_from(attribs) }.not_to raise_error
      end
    end
  end

  describe ".new_request_task" do
    let(:request_class) { VmRetireRequest }

    it "creates a task with the correct class" do
      attribs = {
        'options'     => {:src_ids => [vm.id]},
        'source_id'   => vm.id,
        'source_type' => 'Vm'
      }

      task = request_class.new_request_task(attribs)
      expect(task).to be_a(VmRetireTask)
      expect(task.source_id).to eq(vm.id)
    end
  end
end
