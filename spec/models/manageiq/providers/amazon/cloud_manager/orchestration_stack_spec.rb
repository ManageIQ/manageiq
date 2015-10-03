require "spec_helper"

describe ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack do
  let(:ems) { FactoryGirl.create(:ems_amazon) }
  let(:template) { FactoryGirl.create(:orchestration_template) }
  let(:orchestration_stack) do
    FactoryGirl.create(:orchestration_stack_amazon, :ext_management_system => ems, :name => 'test')
  end

  let(:the_raw_stack) do
    double.tap do |stack|
      allow(stack).to receive(:stack_id).and_return('one_id')
    end
  end

  let(:raw_stacks) do
    double.tap do |stacks|
      handle = double
      allow(handle).to receive(:stacks).and_return(stacks)
      allow(ems).to receive(:connect).and_return(handle)
      allow(stacks).to receive(:[]).with(orchestration_stack.name).and_return(the_raw_stack)
    end
  end

  before do
    raw_stacks
  end

  describe 'stack operations' do
    context ".create_stack" do
      it 'creates a stack' do
        expect(raw_stacks).to receive(:create).and_return(the_raw_stack)

        stack = OrchestrationStack.create_stack(ems, 'mystack', template, {})
        stack.class.should == described_class
        stack.name.should == 'mystack'
        stack.ems_ref.should == the_raw_stack.stack_id
      end

      it 'catches errors from provider' do
        expect(raw_stacks).to receive(:create).and_throw('bad request')

        expect { OrchestrationStack.create_stack(ems, 'mystack', template, {}) }.to raise_error(MiqException::MiqOrchestrationProvisionError)
      end
    end

    context "#update_stack" do
      it 'updates the stack' do
        expect(the_raw_stack).to receive(:update)
        orchestration_stack.update_stack({})
      end

      it 'catches errors from provider' do
        expect(the_raw_stack).to receive(:update).and_throw('bad request')
        expect { orchestration_stack.update_stack }.to raise_error(MiqException::MiqOrchestrationUpdateError)
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
        allow(the_raw_stack).to receive(:status).and_return('CREATE_COMPLETE')
        allow(the_raw_stack).to receive(:status_reason).and_return('complete')

        rstatus = orchestration_stack.raw_status
        expect(rstatus).to have_attributes(:status => 'CREATE_COMPLETE', :reason => 'complete')

        orchestration_stack.raw_exists?.should be_true
      end

      it 'parses error message to determine stack not exist' do
        allow(raw_stacks).to receive(:[]).with(orchestration_stack.name).and_throw("Stack xxx does not exist")
        expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStackNotExistError)

        orchestration_stack.raw_exists?.should be_false
      end

      it 'catches errors from provider' do
        allow(raw_stacks).to receive(:[]).with(orchestration_stack.name).and_throw("bad request")
        expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStatusError)

        expect { orchestration_stack.raw_exists? }.to raise_error(MiqException::MiqOrchestrationStatusError)
      end
    end
  end
end
