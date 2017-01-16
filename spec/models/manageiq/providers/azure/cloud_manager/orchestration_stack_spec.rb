require 'azure-armrest'

describe ManageIQ::Providers::Azure::CloudManager::OrchestrationStack do
  let(:ems) { FactoryGirl.create(:ems_azure_with_authentication) }
  let(:template) { FactoryGirl.create(:orchestration_template_azure_with_content) }
  let(:orchestration_service) { double }
  let(:the_raw_stack) do
    Azure::Armrest::TemplateDeployment.new(
      'id'         => 'one_id',
      'properties' => {'provisioningState' => 'Succeeded'}
    )
  end
  subject { FactoryGirl.create(:orchestration_stack_azure, :ext_management_system => ems, :name => 'test') }


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

    describe ".create_stack" do
      it 'creates a stack' do
        expect(orchestration_service).to receive(:create).and_return(the_raw_stack)

        stack = ManageIQ::Providers::CloudManager::OrchestrationStack.create_stack(ems, 'mystack', template, {})
        expect(stack.class).to   eq(described_class)
        expect(stack.name).to    eq('mystack')
        expect(stack.ems_ref).to eq(the_raw_stack.id)
      end

      it 'catches errors from provider' do
        expect(orchestration_service).to receive(:create).and_raise('bad request')

        expect do
          ManageIQ::Providers::CloudManager::OrchestrationStack.create_stack(ems, 'mystack', template, {})
        end.to raise_error(MiqException::MiqOrchestrationProvisionError)
      end
    end

    describe "#update_stack" do
      it 'updates the stack' do
        expect(orchestration_service).to receive(:create)
        subject.update_stack(template, {})
      end

      it 'catches errors from provider' do
        expect(orchestration_service).to receive(:create).and_raise('bad request')
        expect { subject.update_stack(template, {}) }.to raise_error(MiqException::MiqOrchestrationUpdateError)
      end
    end

    describe "#delete_stack" do
      it 'updates the stack' do
        expect(orchestration_service).to receive(:delete_associated_resources)
        subject.delete_stack
      end

      it 'catches errors from provider' do
        expect(orchestration_service).to receive(:delete_associated_resources).and_raise('bad request')
        expect { subject.delete_stack }.to raise_error(MiqException::MiqOrchestrationDeleteError)
      end
    end
  end

  describe 'stack status' do
    describe '#raw_status and #raw_exists' do
      context 'stack is created successfully' do
        before { allow(orchestration_service).to receive(:get).and_return(the_raw_stack) }

        it 'gets the stack status in success' do
          expect(subject.raw_status).to have_attributes(:status => 'Succeeded', :reason => nil)
          expect(subject.raw_exists?).to be_truthy
        end
      end

      context 'stack creation failed' do
        before do
          bad_raw_stack = Azure::Armrest::TemplateDeployment.new('properties' => {'provisioningState' => 'Failed'})
          operations = [Azure::Armrest::TemplateDeploymentOperation.new('properties' => { 'statusMessage' => 'reason'})]
          allow(orchestration_service).to receive(:get).and_return(bad_raw_stack)
          allow(orchestration_service).to receive(:list_deployment_operations).and_return(operations)
        end

        it 'gets the stack status in failure and finds its cause' do
          expect(subject.raw_status).to have_attributes(:status => 'Failed', :reason => 'reason')
          expect(subject.raw_exists?).to be_truthy
        end
      end

      it 'parses error message to determine stack not exist' do
        allow(orchestration_service).to receive(:get).and_raise("Deployment xxx could not be found")
        expect { subject.raw_status }.to raise_error(MiqException::MiqOrchestrationStackNotExistError)

        expect(subject.raw_exists?).to be_falsey
      end

      it 'catches errors from provider' do
        allow(orchestration_service).to receive(:get).and_raise("bad request")
        expect { subject.raw_status }.to raise_error(MiqException::MiqOrchestrationStatusError)

        expect { subject.raw_exists? }.to raise_error(MiqException::MiqOrchestrationStatusError)
      end
    end
  end

  describe '.deployment_failed?' do
    let(:deployment) do
      Azure::Armrest::TemplateDeployment.new(
        'id'         => 'one_id',
        'properties' => {'provisioningState' => testing_status}
      )
    end

    context 'with succeeded deployment' do
      let(:testing_status) { 'Succeeded' }

      it { expect(subject.deployment_failed?(deployment)).to be_falsey }
    end

    context 'with failed deployment' do
      let(:testing_status) { 'Failed' }

      it { expect(subject.deployment_failed?(deployment)).to be_truthy }
    end
  end

  describe '.deployment_failure_reason' do
    let(:operations) do
      [Azure::Armrest::TemplateDeploymentOperation.new(
        'id'         => 'one',
        'properties' => { 'statusMessage' => testing_message }
      )]
    end

    context 'without failure operation' do
      let(:testing_message) { nil }

      it { expect(subject.deployment_failure_reason(operations)).to be_nil }
    end

    context 'operation has explicit error message' do
      let(:testing_message) { {'error' => {'message' => 'some reason'}} }

      it { expect(subject.deployment_failure_reason(operations)).to eq('some reason') }
    end

    context 'operation has general (error) message' do
      let(:testing_message) { 'some reason' }

      it { expect(subject.deployment_failure_reason(operations)).to eq('some reason') }
    end
  end
end
