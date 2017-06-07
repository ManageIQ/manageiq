#
# Description: This method provisions a container using a template
#
unless defined? ManageIQ::Automate::Container::Service::Provisioning::StateMachines::Provision
  module ManageIQ
    module Automate
      module Container
        module Service
          module Provisioning
            module StateMachines
              module Provision
              end
            end
          end
        end
      end
    end
  end
end

class ManageIQ::Automate::Container::Service::Provisioning::StateMachines::Provision::OpenshiftProvision
  def initialize(handle)
    @handle = handle
  end

  def main
    @handle.log("info", "Starting OpenShift Provisioning")
    run(task, service)
  end

  private

  def task
    @handle.root["service_template_provision_task"].tap do |task|
      raise "service_template_provision_task not found" unless task
    end
  end

  def service
    task.destination.tap do |service|
      # TODO: add validation whether service is the right type, raise an error if not
    end
  end

  def run(task, service)
    # TODO: add logic to do the actual provisioning
  rescue => err
    @handle.root['ae_result'] = 'error'
    @handle.root['ae_reason'] = err.message
    @handle.log("error", "OpenShift Provisioning failed. Reason: #{err.message}")
  end
end

if __FILE__ == $PROGRAM_NAME
  ManageIQ::Automate::Container::Service::Provisioning::StateMachines::Provision::OpenshiftProvision.new($evm).main
end
