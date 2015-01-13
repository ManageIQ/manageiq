class ApiController
  module Action
    private

    def api_action(type, id, options = {})
      cspec = collection_config[type]
      klass = cspec[:klass].constantize

      result = yield(klass) if block_given?

      add_href_to_result(result, type, id) unless options[:skip_href]
      log_result(result)
      result
    end

    def queue_object_action(object, summary, options)
      task_options = {
        :action => summary,
        :userid => @auth_user
      }

      queue_options = {
        :class_name  => options[:class_name],
        :method_name => options[:method_name],
        :instance_id => object.id,
        :args        => options[:args] || [],
        :role        => options[:role] || nil,
      }

      MiqTask.generic_action_with_callback(task_options, queue_options)
    end
  end
end
