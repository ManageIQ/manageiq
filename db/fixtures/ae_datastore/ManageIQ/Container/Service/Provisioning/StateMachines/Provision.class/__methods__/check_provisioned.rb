#
# Description: This method checks to see if OpenShift container has been provisioned
# and refresh the provider
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

class ManageIQ::Automate::Container::Service::Provisioning::StateMachines::Provision::OpenshiftCheckProvisioned
  def initialize(handle)
    @handle = handle
  end

  def main
    @handle.log("info", "Checking status of OpenShift Provisioning")
    check_provisioned(task, service)
  end

  private

  def check_provisioned(task, service)
    # TODO: add logic to check whether container has been created and then start refresh
  end

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
end

if __FILE__ == $PROGRAM_NAME
  ManageIQ::Automate::Container::Service::Provisioning::StateMachines::Provision::OpenshiftCheckProvisioned.new($evm).main
end
