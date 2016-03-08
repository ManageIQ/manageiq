describe ManageIQ::Providers::Azure::CloudManager::OrchestrationStack do
  let(:ems) { FactoryGirl.create(:ems_azure_with_authentication) }
  let(:template) { FactoryGirl.create(:orchestration_template_azure_with_content) }
  let(:orchestration_stack) do
    FactoryGirl.create(:orchestration_stack_azure, :ext_management_system => ems, :name => 'test')
  end
  let(:orchestration_service) { double }
  let(:the_raw_stack) do
    Azure::Armrest::TemplateDeployment.new(
      'id'         => 'one_id',
      'properties' => {'provisioningState' => 'Succeeded'}
    )
  end

  before do
    allow(ManageIQ::Providers::Azure::CloudManager).to receive(:raw_connect).and_return(double)
    allow(Azure::Armrest::TemplateDeploymentService).to receive(:new).and_return(orchestration_service)
  end

  describe 'stack operations' do
    before do
      rg = double
      allow(Azure::Armrest::ResourceGroupService).to receive(:new).and_return(rg)
      allow(rg).to receive(:create)
    end

    context ".create_stack" do
      it 'creates a stack' do
        expect(orchestration_service).to receive(:create).and_return(the_raw_stack)

        stack = ManageIQ::Providers::CloudManager::OrchestrationStack.create_stack(ems, 'mystack', template, {})
        expect(stack.class).to   eq(described_class)
        expect(stack.name).to    eq('mystack')
        expect(stack.ems_ref).to eq(the_raw_stack.id)
      end

      it 'catches errors from provider' do
        expect(orchestration_service).to receive(:create).and_throw('bad request')

        expect do
          ManageIQ::Providers::CloudManager::OrchestrationStack.create_stack(ems, 'mystack', template, {})
        end.to raise_error(MiqException::MiqOrchestrationProvisionError)
      end
    end

    context "#update_stack" do
      it 'updates the stack' do
        expect(orchestration_service).to receive(:create)
        orchestration_stack.update_stack(template, {})
      end

      it 'catches errors from provider' do
        expect(orchestration_service).to receive(:create).and_throw('bad request')
        expect { orchestration_stack.update_stack(template, {}) }.to raise_error(MiqException::MiqOrchestrationUpdateError)
      end
    end

    context "#delete_stack" do
      it 'updates the stack' do
        expect(orchestration_service).to receive(:delete)
        orchestration_stack.delete_stack
      end

      it 'catches errors from provider' do
        expect(orchestration_service).to receive(:delete).and_throw('bad request')
        expect { orchestration_stack.delete_stack }.to raise_error(MiqException::MiqOrchestrationDeleteError)
      end
    end
  end

  describe 'stack status' do
    context '#raw_status and #raw_exists' do
      it 'gets the stack status and reason' do
        allow(orchestration_service).to receive(:get).and_return(the_raw_stack)

        rstatus = orchestration_stack.raw_status
        expect(rstatus).to have_attributes(:status => 'Succeeded', :reason => nil)

        expect(orchestration_stack.raw_exists?).to be_truthy
      end

      it 'parses error message to determine stack not exist' do
        allow(orchestration_service).to receive(:get).and_throw("Deployment xxx could not be found")
        expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStackNotExistError)

        expect(orchestration_stack.raw_exists?).to be_falsey
      end

      it 'catches errors from provider' do
        allow(orchestration_service).to receive(:get).and_throw("bad request")
        expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStatusError)

        expect { orchestration_stack.raw_exists? }.to raise_error(MiqException::MiqOrchestrationStatusError)
      end
    end
  end
end
