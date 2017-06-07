#
# Description: This method examines the AnsibleTower job provisioned
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

class ManageIQ::Automate::Container::Service::Provisioning::StateMachines::Provision::OpenshiftPostProvision
  def initialize(handle)
    @handle = handle
  end

  def main
    @handle.log("info", "Starting OpenShift Post-Provisioning")

    # for example, dump the info of the resulting container
    # examine_container(task, service)
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
end

if __FILE__ == $PROGRAM_NAME
  ManageIQ::Automate::Container::Service::Provisioning::StateMachines::Provision::OpenshiftPostProvision.new($evm).main
end
