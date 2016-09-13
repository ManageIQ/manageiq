describe ManageIQ::Providers::Vmware::CloudManager::OrchestrationStack do
  let(:ems) { FactoryGirl.create(:ems_vmware_cloud) }
  let(:template) { FactoryGirl.create(:orchestration_template_vmware_cloud) }
  let(:orchestration_stack) do
    FactoryGirl.create(:orchestration_stack_vmware_cloud,
                       :ext_management_system => ems,
                       :name                  => 'test',
                       :ems_ref               => 'one_id')
  end

  let(:the_raw_stack) { double(:id => 'one_id', :human_status => 'on') }

  let(:raw_stacks) do
    double.tap do |stacks|
      allow(stacks).to receive(:get_single_vapp).with(orchestration_stack.ems_ref).and_return(the_raw_stack)
    end
  end

  let(:orchestration_service) do
    double.tap do |service|
      allow(service).to receive(:vapps).and_return(raw_stacks)
      allow(service).to receive(:instantiate_template).and_return(the_raw_stack.id)
    end
  end

  before do
    allow(ems).to receive(:connect).and_return(orchestration_service)
  end

  describe 'stack operations' do
    context ".create_stack" do
      let(:the_new_stack) { double }
      let(:stack_option) { {:vdc_id => 'vdc_id'} }

      it 'creates a stack' do
        stack = ManageIQ::Providers::CloudManager::OrchestrationStack.create_stack(ems, 'mystack', template, stack_option)
        expect(stack.class).to eq(described_class)
        expect(stack.name).to eq('mystack')
        expect(stack.ems_ref).to eq(the_raw_stack.id)
      end

      it 'catches error from provider' do
        expect(orchestration_service).to receive(:instantiate_template).and_raise('bad request')

        expect do
          ManageIQ::Providers::CloudManager::OrchestrationStack.create_stack(ems, 'mystack', template, {})
        end.to raise_error(MiqException::MiqOrchestrationProvisionError)
      end
    end

    context '#delete_stack' do
      it 'deletes the stack' do
        expect(the_raw_stack).to receive(:undeploy)
        expect(the_raw_stack).to receive(:destroy)
        orchestration_stack.delete_stack
      end

      it 'catches errors from provider' do
        expect(the_raw_stack).to receive(:undeploy)
        expect(the_raw_stack).to receive(:destroy).and_raise('bad_request')
        expect { orchestration_stack.delete_stack }.to raise_error(MiqException::MiqOrchestrationDeleteError)
      end
    end
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
