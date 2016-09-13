module Spec
  module Support
    module ButtonHelper
      def setup_view_context_with_sandbox(sandbox)
        view_context = double('ApplicationHelper')
        view_context.class.send(:include, ApplicationHelper)
        view_context.instance_eval { @sb = sandbox }
        view_context
      end
    end
  end
end
