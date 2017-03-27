module Api
  module Subcollections
    module OrchestrationStacks
      def orchestration_stacks_query_resource(object)
        object.orchestration_stacks
      end

      #
      # Virtual attribute accessors
      #
      def fetch_orchestration_stacks_stdout(resource)
        resource.stdout(attribute_format("stdout"))
      end
    end
  end
end
