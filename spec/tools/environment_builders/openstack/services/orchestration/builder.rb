require_relative 'data'

module Openstack
  module Services
    module Orchestration
      class Builder
        attr_reader :service, :volumes

        def self.build_all(ems, project, network)
          new(ems, project, network).build_all
        end

        def initialize(ems, project, network)
          @service = ems.connect(:tenant_name => project.name, :service => "Orchestration")
          @data    = Data.new
          @project = project

          @networks = network.networks

          # Collected data
          @stacks = []
        end

        def build_all
          find_or_create_stacks(@networks)

          self
        end

        private

        def find_or_create_stacks(networks)
          @data.stacks.each do |stack|
            if (network_name = stack[:parameters].delete(:__network_name))
              stack[:parameters]["network_id"] = networks.detect { |x| x.name == network_name }.try(:id)
            end

            @stacks << find_or_create(@service.stacks, stack)
          end
          wait_for_stacks(@stacks)
        end

        def wait_for_stacks(stacks)
          stacks.each { |stack| wait_for_stack(stack) }
        end

        def wait_for_stack(stack)
          stack_id = stack.kind_of?(Hash) ? stack['id'] : stack.id

          print "Waiting for stack #{stack_id} to get in a desired state..."

          loop do
            # TODO(lsmola) stack.create doesn return a model, so we are obtaining it via list.
            # Stack model needs to be fixed. Then uncomment this:
            # case server.reload.stack_status
            case @service.stacks.detect { |x| x.id == stack_id }.try(:stack_status)
            when "CREATE_COMPLETE", "UPDATE_COMPLETE"
              break
            when "CREATE_FAILED", "UPDATE_FAILED"
              puts "Error creating stack"
              exit 1
            else
              print "."
              sleep 1
            end
          end
          puts "Finished"
        end
      end
    end
  end
end
