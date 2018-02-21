module Api
  class BaseController
    module Action
      private

      def api_action(type, id, options = {})
        klass = collection_class(type)

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
          :class_name  => options[:class_name] || object.class.name,
          :method_name => options[:method_name],
          :instance_id => object.id,
          :args        => options[:args] || [],
          :role        => options[:role] || nil,
        }

        queue_options[:zone] = object.my_zone if %w(ems_operations smartstate).include?(options[:role])

        MiqTask.generic_action_with_callback(task_options, queue_options)
      end

      def queue_options(method, role = nil)
        {
          :method_name => method,
          :role        => role,
          :user        => {
            :user_id   => current_user.id,
            :group_id  => current_user.current_group.id,
            :tenant_id => current_user.current_tenant.id
          }
        }
      end
    end
  end
end
