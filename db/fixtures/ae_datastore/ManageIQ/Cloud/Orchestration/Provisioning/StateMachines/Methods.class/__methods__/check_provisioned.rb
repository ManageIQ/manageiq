#
# Description: This class checks to see if the stack has been provisioned
#   and whether the refresh has completed
#
module ManageIQ
  module Automate
    module Cloud
      module Orchestration
        module Provisioning
          module StateMachines
            class CheckProvisioned
              def initialize(handle = $evm)
                @handle = handle
              end

              def main
                task = @handle.root["service_template_provision_task"]
                service = task.try(:destination)

                unless service
                  @handle.log(:error, 'Service is nil')
                  raise 'Service is nil'
                end

                unless service.instance_of?(MiqAeMethodService::MiqAeServiceServiceOrchestration)
                  @handle.log(:error, 'Service has a different type from MiqAeServiceServiceOrchestration')
                  raise 'Service has a different type from MiqAeServiceServiceOrchestration'
                end

                if @handle.state_var_exist?('provider_last_refresh')
                  check_refreshed(service)
                else
                  check_deployed(service)
                end

                unless @handle.root['ae_reason'].blank?
                  task.miq_request.user_message = @handle.root['ae_reason'].truncate(255)
                end
              end

              private

              def prepare_and_call_refresh_provider(service)
                @handle.set_state_var('deploy_result', @handle.root['ae_result'])
                @handle.set_state_var('deploy_reason', @handle.root['ae_reason'])

                refresh_provider(service)

                @handle.root['ae_result']         = 'retry'
                @handle.root['ae_retry_interval'] = '30.seconds'
              end

              def refresh_provider(service)
                provider = service.orchestration_manager

                @handle.log("info", "Refreshing provider #{provider.name}")
                @handle.set_state_var('provider_last_refresh', provider.last_refresh_date.to_i)
                provider.refresh
              end

              def refresh_may_have_completed?(service)
                stack = service.orchestration_stack
                refreshed_stack = @handle.vmdb(:orchestration_stack).find_by(:name    => stack.name,
                                                                             :ems_ref => stack.ems_ref)
                refreshed_stack && refreshed_stack.status != 'CREATE_IN_PROGRESS'
              end

              def check_deployed(service)
                @handle.log("info", "Check orchestration deployed")

                return unless deployment_completed?(service)
                @handle.log("info", "Stack deployment finished. Status: " \
                                    "#{@handle.root['ae_result']}, reason: #{@handle.root['ae_reason']}")

                if @handle.root['ae_result'] == 'error'
                  @handle.log("info", "Please examine stack resources for more details")
                end

                return unless service.orchestration_stack
                prepare_and_call_refresh_provider(service)
              end

              def deployment_completed?(service)
                # check whether the stack deployment completed
                status, reason = service.orchestration_stack_status
                case status.downcase
                when 'create_complete'
                  @handle.root['ae_result'] = 'ok'
                when 'rollback_complete', 'delete_complete', /failed$/, /canceled$/
                  @handle.root['ae_result'] = 'error'
                  @handle.root['ae_reason'] = reason
                else
                  # deployment not done yet in provider
                  @handle.root['ae_result']         = 'retry'
                  @handle.root['ae_retry_interval'] = '1.minute'
                  return false
                end
                true
              end

              def check_refreshed(service)
                @handle.log("info", "Check refresh status of stack (#{service.stack_name})")

                if refresh_may_have_completed?(service)
                  @handle.root['ae_result'] = @handle.get_state_var('deploy_result')
                  @handle.root['ae_reason'] = @handle.get_state_var('deploy_reason')
                  @handle.log("info", "Refresh completed.")
                else
                  @handle.root['ae_result']         = 'retry'
                  @handle.root['ae_retry_interval'] = '30.seconds'
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
  ManageIQ::Automate::Cloud::Orchestration::Provisioning::StateMachines::CheckProvisioned.new.main
end
