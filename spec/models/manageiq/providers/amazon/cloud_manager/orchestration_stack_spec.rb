require_relative "../aws_helper"

describe ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack do
  let(:ems) { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:template) { FactoryGirl.create(:orchestration_template) }
  let(:orchestration_stack) do
    FactoryGirl.create(:orchestration_stack_amazon, :ext_management_system => ems, :name => 'test')
  end

  describe 'stack operations' do
    context ".raw_create_stack" do
      it "creates a stack" do
        stubbed_responses = {
            :cloudformation => {
                :create_stack => [:stack_id => "stack_id"],
                :describe_stacks => {
                    :stacks =>
                        [
                            :stack_name => "mystack",
                            :creation_time => 10.minutes.ago,
                            :stack_status => 'CREATE_COMPLETE',
                            :stack_id => "stack_id"
                        ]
                }
            }
        }
        with_aws_stubbed(stubbed_responses) do
          stack = OrchestrationStack.create_stack(ems, "mystack", template)
          expect(stack.class).to eq(described_class)
          expect(stack.name).to eq("mystack")
          expect(stack.ems_ref).to eq("stack_id")
        end
      end

      it 'catches errors from provider' do
        stubbed_responses = {
            :cloudformation => {
                :create_stack => "AlreadyExistsException"
            }
        }
        with_aws_stubbed(stubbed_responses) do
          expect do
            OrchestrationStack.create_stack(ems, "mystack", template)
          end.to raise_error(MiqException::MiqOrchestrationProvisionError)
        end
      end
    end

    context "#update_stack" do
      it 'updates the stack' do
        stubbed_responses = {
            :cloudformation => {
                :update_stack => { :stack_id => "stack_id"}
            }
        }
        with_aws_stubbed(stubbed_responses) do
          expect(orchestration_stack.update_stack(template, {}).stack_id).to eq("stack_id")
        end
      end

      it "catches errors from provider" do
        stubbed_responses = {
            :cloudformation => {
                :update_stack => "ServiceError"
            }
        }
        with_aws_stubbed(stubbed_responses) do
          expect do
            orchestration_stack.update_stack(template, {})
          end.to raise_error(MiqException::MiqOrchestrationUpdateError)
        end
      end
    end

    context "#delete_stack" do
      it "deletes the stack" do
        stubbed_responses = {
            :cloudformation => {
                :delete_stack => {}
            }
        }
        with_aws_stubbed(stubbed_responses) do
          expect(orchestration_stack.delete_stack).to be_truthy
        end
      end

      it 'catches errors from provider' do
        stubbed_responses = {
            :cloudformation => {
                :delete_stack => "InsufficientCapabilitiesException"
            }
        }
        with_aws_stubbed(stubbed_responses) do
          expect do
            orchestration_stack.delete_stack
          end.to raise_error(MiqException::MiqOrchestrationDeleteError)
        end
      end
    end
  end

  describe 'stack status' do
    context '#raw_status and #raw_exists' do
      it 'gets the stack status and reason' do
        stubbed_responses = {
            :cloudformation => {
                :describe_stacks => {
                    :stacks => [
                        :stack_name => "StackName",
                        :creation_time => 10.minutes.ago,
                        :stack_status => 'CREATE_COMPLETE',
                        :stack_status_reason => 'complete'
                    ]
                }
            }
        }
        with_aws_stubbed(stubbed_responses) do
          raw_status = orchestration_stack.raw_status

          expect(raw_status).to have_attributes(:status => 'CREATE_COMPLETE', :reason => 'complete')
          expect(orchestration_stack.raw_exists?).to be_truthy
        end
      end

      it 'parses error message to determine stack not exist' do
        stubbed_responses = {
            :cloudformation => {
                :describe_stacks => Aws::CloudFormation::Errors::ValidationError.new(:no_context, "Stack with id stack_id does not exist")
            }
        }
        with_aws_stubbed(stubbed_responses) do
          expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStackNotExistError)
          expect(orchestration_stack.raw_exists?).to be_falsey
        end
      end

      it 'catches errors from provider' do
        stubbed_responses = {
            :cloudformation => {
                :describe_stacks => "ServiceError"
            }
        }
        with_aws_stubbed(stubbed_responses) do
          expect { orchestration_stack.raw_status }.to raise_error(MiqException::MiqOrchestrationStatusError)
          expect { orchestration_stack.raw_exists? }.to raise_error(MiqException::MiqOrchestrationStatusError)
        end
      end
    end
  end
end
