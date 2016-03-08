describe ManageIQ::Providers::Openstack::CloudManager::OrchestrationStack do
  let(:ems) { FactoryGirl.create(:ems_openstack) }
  let(:template) { FactoryGirl.create(:orchestration_template) }
  let(:tenant) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems) }
  let(:orchestration_stack) do
    FactoryGirl.create(:orchestration_stack_openstack,
      :ext_management_system => ems, :name => 'test', :ems_ref => 'one_id', :cloud_tenant => tenant)
  end

  let(:the_raw_stack) do
    double.tap do |stack|
      allow(stack).to receive(:id).and_return('one_id')
    end
  end

  let(:raw_stacks) do
    double.tap do |stacks|
      handle = double
      allow(handle).to receive(:stacks).and_return(stacks)
      allow(ems).to receive(:connect).with(hash_including(:tenant_name => tenant.name)).and_return(handle)
      allow(stacks).to receive(:get).with(orchestration_stack.name, orchestration_stack.ems_ref).and_return(the_raw_stack)
    end
  end

  before do
    raw_stacks
  end

  describe 'stack operations' do
    context ".create_stack" do
      let(:the_new_stack) { double }
      let(:stack_option) { {:tenant_name => tenant.name} }

      before do
        allow(raw_stacks).to receive(:new).and_return(the_new_stack)
      end

      it 'creates a stack' do
        allow(the_new_stack).to receive(:[]).with("id").and_return('new_id')
        expect(the_new_stack).to receive(:save).and_return(the_new_stack)

        stack = ManageIQ::Providers::CloudManager::OrchestrationStack.create_stack(ems, 'mystack', template, stack_option)
        expect(stack.class).to eq(described_class)
        expect(stack.name).to eq('mystack')
        expect(stack.ems_ref).to eq('new_id')
        expect(stack.cloud_tenant).to eq(tenant)
      end

      it 'catches errors from provider' do
        expect(the_new_stack).to receive(:save).and_throw('bad request')

        expect do
          ManageIQ::Providers::CloudManager::OrchestrationStack.create_stack(ems, 'mystack', template, stack_option)
        end.to raise_error(MiqException::MiqOrchestrationProvisionError)
      end
    end

    context "#update_stack" do
      it 'updates the stack' do
        expect(the_raw_stack).to receive(:save)
        orchestration_stack.update_stack(template, {})
      end

      it 'catches errors from provider' do
        expect(the_raw_stack).to receive(:save).and_throw('bad request')
        expect { orchestration_stack.update_stack(template, {}) }.to raise_error(MiqException::MiqOrchestrationUpdateError)
      end
    end

    context "#delete_stack" do
      it 'updates the stack' do
        expect(the_raw_stack).to receive(:delete)
        orchestration_stack.delete_stack
      end

      it 'catches errors from provider' do
        expect(the_raw_stack).to receive(:delete).and_throw('bad request')
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
        expect(rstatus).to have_attributes(:status => 'CREATE_COMPLETE', :reason => 'complete')

        expect(orchestration_stack.raw_exists?).to be_truthy
      end

      it 'determines stack not exist' do
        allow(raw_stacks).to receive(:get).with(orchestration_stack.name, orchestration_stack.ems_ref).and_return(nil)
        expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStackNotExistError)

        expect(orchestration_stack.raw_exists?).to be_falsey
      end

      it 'catches errors from provider' do
        allow(raw_stacks).to receive(:get).with(orchestration_stack.name, orchestration_stack.ems_ref).and_throw("bad request")
        expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStatusError)

        expect { orchestration_stack.raw_exists? }.to raise_error(MiqException::MiqOrchestrationStatusError)
      end
    end
  end
end
