module EmsRefresh
  module Parsers
    module OpenstackCommon
      module OrchestrationStacks
        def stack_resources(stack)
          return @resources[stack.id] if @resources && !@resources.fetch_path(stack.id).blank?
          @resources = {} unless @resources
          @resources[stack.id] = stack.resources
        end

        def load_orchestration_stacks
          process_collection(stacks, :orchestration_stacks) { |stack| parse_stack(stack) }
          update_nested_stack_relations
        end

        private

        def stacks
          @stacks ||= detailed_stacks
        end

        def detailed_stacks
          return [] unless @orchestration_service
          # TODO(lsmola) We need a support of GET /{tenant_id}/stacks/detail in FOG, it was implemented here
          # https://review.openstack.org/#/c/35034/, but never documented in API reference, so right now we
          # can't get list of detailed stacks in one API call.
          @orchestration_service.stacks.all(:show_nested => true).collect(&:details)
        rescue Excon::Errors::Forbidden
          # Orchestration service is detected but not open to the user
          $log.warn("Skip refreshing stacks because the user cannot access the orchestration service")
          []
        end

        def parse_stack(stack)
          uid = stack.id.to_s
          resources = find_stack_resources(stack)

          orchestration_stack_type = case @ems
                                     when EmsOpenstack
                                       "OrchestrationStackOpenstack"
                                     when EmsOpenstackInfra
                                       "OrchestrationStackOpenstackInfra"
                                     else
                                       "OrchestrationStack"
                                     end

          new_result = {
            :type                   => orchestration_stack_type,
            :ems_ref                => uid,
            :name                   => stack.stack_name,
            :description            => stack.description,
            :status                 => stack.stack_status,
            :status_reason          => stack.stack_status_reason,
            # TODO(lsmola) expose attribute parent in Fog and change this to stack.attribute
            :parent_stack_id        => stack.attributes['parent'],
            :resources              => resources,
            :outputs                => find_stack_outputs(stack),
            :parameters             => find_stack_parameters(stack),
            :orchestration_template => find_stack_template(stack)
          }
          return uid, new_result
        end

        def parse_stack_template(stack)
          # Only need a temporary unique identifier for the template. Using the stack id is the cheapest way.
          uid = stack.id
          template = stack.template
          template_type = template.format == "HOT" ? "OrchestrationTemplateHot" : "OrchestrationTemplateCfn"

          new_result = {
            :type        => template_type,
            :name        => stack.stack_name,
            :description => template.description,
            :content     => template.content
          }
          return uid, new_result
        end

        def parse_stack_parameter(param_key, param_val, stack_id)
          uid = compose_ems_ref(stack_id, param_key)
          new_result = {
            :ems_ref => uid,
            :name    => param_key,
            :value   => param_val
          }
          return uid, new_result
        end

        def parse_stack_output(output, stack_id)
          uid = compose_ems_ref(stack_id, output['output_key'])
          new_result = {
            :ems_ref     => uid,
            :key         => output['output_key'],
            :value       => output['output_value'],
            :description => output['description']
          }
          return uid, new_result
        end

        def parse_stack_resource(resource)
          # TODO(lsmola) expose physical_resource_id in Fog and replace all occurrences with
          # resource.physical_resource_id
          uid = resource.attributes['physical_resource_id']
          new_result = {
            :ems_ref                => uid,
            :logical_resource       => resource.logical_resource_id,
            :physical_resource      => uid,
            :resource_category      => resource.resource_type,
            :resource_status        => resource.resource_status,
            :resource_status_reason => resource.resource_status_reason,
            :last_updated           => resource.updated_time
          }
          return uid, new_result
        end

        def get_stack_parameters(stack_id, parameters)
          process_collection(parameters, :orchestration_stack_parameters) do |param_key, param_val|
            parse_stack_parameter(param_key, param_val, stack_id)
          end
        end

        def get_stack_outputs(stack_id, outputs)
          process_collection(outputs, :orchestration_stack_outputs) do |output|
            parse_stack_output(output, stack_id)
          end
        end

        def get_stack_resources(resources)
          process_collection(resources, :orchestration_stack_resources) { |resource| parse_stack_resource(resource) }
        end

        def get_stack_template(stack)
          process_collection([stack], :orchestration_templates) { |the_stack| parse_stack_template(the_stack) }
        end

        def find_stack_parameters(stack)
          raw_parameters = stack.parameters
          get_stack_parameters(stack.id, raw_parameters)
          raw_parameters.collect do |parameter|
            @data_index.fetch_path(:orchestration_stack_parameters, compose_ems_ref(stack.id, parameter[0]))
          end
        end

        def find_stack_template(stack)
          get_stack_template(stack)
          @data_index.fetch_path(:orchestration_templates, stack.id)
        end

        def find_stack_outputs(stack)
          raw_outputs = stack.outputs || []
          get_stack_outputs(stack.id, raw_outputs)
          raw_outputs.collect do |output|
            @data_index.fetch_path(:orchestration_stack_outputs, compose_ems_ref(stack.id, output['output_key']))
          end
        end

        def find_stack_resources(stack)
          # convert the AWS Resource Summary collection to an array to avoid the same API getting called twice
          raw_resources = stack_resources(stack)

          # physical_resource_id can be empty if the resource was not successfully created; ignore such
          raw_resources.reject! { |r| r.attributes['physical_resource_id'].nil? }

          get_stack_resources(raw_resources)

          raw_resources.collect do |resource|
            physical_id = resource.attributes['physical_resource_id']
            @data_index.fetch_path(:orchestration_stack_resources, physical_id)
          end
        end

        #
        # Helper methods
        #

        # Remap from children to parent
        def update_nested_stack_relations
          @data[:orchestration_stacks].each do |stack|
            parent_stack = @data_index.fetch_path(:orchestration_stacks, stack[:parent_stack_id])
            stack[:parent] = parent_stack if parent_stack
            stack.delete(:parent_stack_id)
          end
        end

        # Compose an ems_ref combining some existing keys
        def compose_ems_ref(*keys)
          keys.join('_')
        end
      end
    end
  end
end
