#
# Description: This method prepares arguments and parameters for an OpenShift provisioning
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

class ManageIQ::Automate::Container::Service::Provisioning::StateMachines::Provision::OpenshiftPreprovision
  def initialize(handle)
    @handle = handle
  end

  def main
    @handle.log("info", "Starting Openshift Pre-Provisioning")
    examine_request(service)
    # modify_request(service)
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

  # Through service you can examine the template, openshift manager (aka provider)
  # and options to start a job
  def examine_request(service)
    # TODO: Add sample code here. Log user options from the service dialog.
    # Cation: avoid logging sensitive information such as password
  end

  # You can make further modification to options not available in service dialog
  # or override user's selections base on some policies
  def modify_request(service)
    # TODO: Add sample code here
  end
end

if __FILE__ == $PROGRAM_NAME
  ManageIQ::Automate::Container::Service::Provisioning::StateMachines::Provision::OpenshiftPreprovision.new($evm).main
end
