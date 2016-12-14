#
# Description: This method launches the orchestration provisioning job
#
module ManageIQ
  module Automate
    module Cloud
      module Orchestration
        module Provisioning
          module StateMachines
            class Provision
              def initialize(handle = $evm)
                @handle = handle
              end

              def main
                @handle.log("info", "Starting Orchestration Provisioning")

                task = @handle.root["service_template_provision_task"]
                service = task.destination

                begin
                  stack = service.deploy_orchestration_stack
                  @handle.log("info",
                              "Stack #{service.stack_name} with reference id (#{stack.ems_ref}) is being created")
                rescue => err
                  @handle.root['ae_result'] = 'error'
                  @handle.root['ae_reason'] = err.message
                  task.miq_request.user_message = err.message.truncate(255)
                  @handle.log("error", "Stack #{service.stack_name} creation failed. Reason: #{err.message}")
                end
              end
            end
          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  ManageIQ::Automate::Cloud::Orchestration::Provisioning::StateMachines::Provision.new.main
end
