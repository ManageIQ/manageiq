module Api
  class BaseController
    module ProvisionRequests
      def create_resource_provision_requests(type, _id, data)
        assert_id_not_specified(data, type)

        version_str       = data["version"] || "1.1"
        template_fields   = hash_fetch(data, "template_fields")
        vm_fields         = hash_fetch(data, "vm_fields")
        requester         = hash_fetch(data, "requester")
        tags              = hash_fetch(data, "tags")
        additional_values = hash_fetch(data, "additional_values")
        ems_custom_attrs  = hash_fetch(data, "ems_custom_attributes")
        miq_custom_attrs  = hash_fetch(data, "miq_custom_attributes")

        MiqProvisionVirtWorkflow.from_ws(version_str, @auth_user_obj, template_fields, vm_fields, requester, tags,
                                         additional_values, ems_custom_attrs, miq_custom_attrs)
      end

      def deny_resource_provision_requests(type, id, data)
        api_action(type, id) do |klass|
          provreq = resource_search(id, type, klass)
          provreq.deny(@auth_user, data['reason'])
          action_result(true, "Provision request #{id} denied")
        end
      rescue => err
        action_result(false, err.to_s)
      end

      def approve_resource_provision_requests(type, id, data)
        api_action(type, id) do |klass|
          provreq = resource_search(id, type, klass)
          provreq.approve(@auth_user, data['reason'])
          action_result(true, "Provision request #{id} approved")
        end
      rescue => err
        action_result(false, err.to_s)
      end
    end
  end
end
