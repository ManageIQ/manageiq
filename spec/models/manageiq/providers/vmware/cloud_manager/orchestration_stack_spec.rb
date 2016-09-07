describe ManageIQ::Providers::Vmware::CloudManager::OrchestrationStack do
  let(:ems) { FactoryGirl.create(:ems_vmware_cloud) }
  let(:orchestration_stack) do
    FactoryGirl.create(:orchestration_stack_vmware_cloud,
                       :ext_management_system => ems,
                       :name                  => 'test',
                       :ems_ref               => 'one_id')
  end

  let(:the_raw_stack) { double(:id => 'one_id', :human_status => 'on') }

  let(:raw_stacks) do
    double.tap do |stacks|
      handle = double
      allow(handle).to receive(:vapps).and_return(stacks)
      allow(ems).to receive(:connect).and_return(handle)
      allow(stacks).to receive(:get_single_vapp).with(orchestration_stack.ems_ref).and_return(the_raw_stack)
    end
  end

  before do
    raw_stacks
  end

  describe 'stack status' do
    context '#raw_status and #raw_exists' do
      it 'gets the stack status and reason' do
        allow(the_raw_stack).to receive(:stack_status).and_return('on')

        rstatus = orchestration_stack.raw_status
        expect(rstatus).to have_attributes(:status => 'on', :reason => nil)

        expect(orchestration_stack.raw_exists?).to be_truthy
      end

      it 'determines stack not exist' do
        allow(raw_stacks).to receive(:get_single_vapp).with(orchestration_stack.ems_ref).and_return(nil)
        expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStackNotExistError)

        expect(orchestration_stack.raw_exists?).to be_falsey
      end

      it 'catches errors from provider' do
        allow(raw_stacks).to receive(:get_single_vapp).with(orchestration_stack.ems_ref).and_raise("bad request")
        expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStatusError)

        expect { orchestration_stack.raw_exists? }.to raise_error(MiqException::MiqOrchestrationStatusError)
      end
    end
  end
end
