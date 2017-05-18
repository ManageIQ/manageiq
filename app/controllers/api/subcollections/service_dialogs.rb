module Api
  module Subcollections
    module ServiceDialogs
      def service_dialogs_query_resource(object)
        object ? object.dialogs : []
      end

      #
      # Virtual attribute accessors
      #
      def fetch_service_dialogs_content(resource)
        case @req.collection
        when "service_templates"
          service_template = parent_resource_obj
        when "services"
          service_template = parent_resource_obj.service_template
        end
        return resource.content if service_template.nil?
        resource_action = service_template.resource_actions.where(:dialog_id => resource.id).first
        if resource_action.nil?
          raise BadRequestError,
                "#{service_dialog_ident(resource)} is not referenced by #{service_template_ident(service_template)}"
        end
        resource.content(service_template, resource_action, true)
      end
    end
  end
end
