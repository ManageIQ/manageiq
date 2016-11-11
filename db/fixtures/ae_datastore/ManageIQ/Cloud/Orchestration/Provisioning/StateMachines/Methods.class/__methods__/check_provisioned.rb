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
                method1()
              end

              private

              def method1
                task = @handle.root["service_template_provision_task"]
                service = task.try(:destination)

                if @handle.state_var_exist?('provider_last_refresh')
                  check_refreshed(service)
                else
                  check_deployed(service)
                end

                task.miq_request.user_message = @handle.root['ae_reason'].truncate(255) unless @handle.root['ae_reason'].blank?
              end


              def refresh_provider(service)
                provider = service.orchestration_manager

                @handle.log("info", "Refreshing provider #{provider.name}")
                @handle.set_state_var('provider_last_refresh', provider.last_refresh_date.to_i)
                provider.refresh
              end

              def refresh_may_have_completed?(service)
                stack = service.orchestration_stack
                refreshed_stack = @handle.vmdb(:orchestration_stack).find_by(:name => stack.name, :ems_ref => stack.ems_ref)
                refreshed_stack && refreshed_stack.status != 'CREATE_IN_PROGRESS'
              end

              def check_deployed(service)
                @handle.log("info", "Check orchestration deployed")
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
                  return
                end

                @handle.log("info", "Stack deployment finished. Status: #{@handle.root['ae_result']}, reason: #{@handle.root['ae_reason']}")
                @handle.log("info", "Please examine stack resources for more details") if @handle.root['ae_result'] == 'error'

                return unless service.orchestration_stack
                @handle.set_state_var('deploy_result', @handle.root['ae_result'])
                @handle.set_state_var('deploy_reason', @handle.root['ae_reason'])

                refresh_provider(service)

                @handle.root['ae_result']         = 'retry'
                @handle.root['ae_retry_interval'] = '30.seconds'
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
