module Api
  module Subcollections
    module OrchestrationStacks
      def orchestration_stacks_query_resource(object)
        object.orchestration_stacks
      end

      def orchestration_stacks_stdout_resource(object, _type, id, _data = nil)
        os = object.orchestration_stacks.find { |os| os.id == id }
        { :stdout => os.raw_stdout }
      end
    end
  end
end
