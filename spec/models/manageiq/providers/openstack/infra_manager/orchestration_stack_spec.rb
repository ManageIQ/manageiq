describe ManageIQ::Providers::Openstack::InfraManager::OrchestrationStack do
  let(:ems) { FactoryGirl.create(:ems_openstack_infra) }
  let(:template) { FactoryGirl.create(:orchestration_template) }
  let(:orchestration_stack) do
    FactoryGirl.create(:orchestration_stack_openstack_infra, :ext_management_system => ems, :name => 'test', :ems_ref => 'one_id')
  end

  let(:the_raw_stack) do
    double.tap do |stack|
      allow(stack).to receive(:id).and_return('one_id')
    end
  end

  let(:handle) { double }

  let(:raw_stacks) do
    double.tap do |stacks|
      fog_template = double
      allow(fog_template).to receive(:body).and_return("test_template")
      allow(handle).to receive(:stacks).and_return(stacks)
      allow(handle).to receive(:get_stack_template).and_return(fog_template)
      allow(ems).to receive(:connect).and_return(handle)
      allow(stacks).to receive(:get).with(orchestration_stack.name, orchestration_stack.ems_ref).and_return(the_raw_stack)
    end
  end

  before do
    raw_stacks
  end

  describe 'stack operations' do
    context ".create_stack" do
      # TBD we don't allow it now
    end

    context "#update_stack" do
      it 'updates the stack' do
        expect(handle).to receive(:patch_stack)
        orchestration_stack.update_stack(nil, {})
      end

      it 'catches errors from provider' do
        expect(handle).to receive(:patch_stack).and_raise('bad request')
        expect { orchestration_stack.update_stack(nil, {}) }.to raise_error(MiqException::MiqOrchestrationUpdateError)
      end
    end

    context "#delete_stack" do
      it 'updates the stack' do
        expect(the_raw_stack).to receive(:delete)
        orchestration_stack.delete_stack
      end

      it 'catches errors from provider' do
        expect(the_raw_stack).to receive(:delete).and_raise('bad request')
        expect { orchestration_stack.delete_stack }.to raise_error(MiqException::MiqOrchestrationDeleteError)
      end
    end
  end

  describe 'stack status' do
    context '#raw_status and #raw_exists' do
      it 'gets the stack status and reason' do
        allow(the_raw_stack).to receive(:stack_status).and_return('CREATE_COMPLETE')
        allow(the_raw_stack).to receive(:stack_status_reason).and_return('complete')

        rstatus = orchestration_stack.raw_status
        expect(rstatus).to eq %w(CREATE_COMPLETE complete)

        # TODO(lsmola) convert status to Status object
        # orchestration_stack.raw_exists?.should be_true
        expect(orchestration_stack.update_ready?).to be_truthy
      end

      it 'determines stack not exist' do
        allow(raw_stacks).to receive(:get).with(orchestration_stack.name, orchestration_stack.ems_ref).and_return(nil)
        expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStackNotExistError)

        expect(orchestration_stack.raw_exists?).to be_falsey
      end

      it 'catches errors from provider' do
        allow(raw_stacks).to receive(:get).with(orchestration_stack.name, orchestration_stack.ems_ref).and_raise("bad request")
        expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStatusError)

        expect { orchestration_stack.raw_exists? }.to raise_error(MiqException::MiqOrchestrationStatusError)
      end
    end
  end
end
