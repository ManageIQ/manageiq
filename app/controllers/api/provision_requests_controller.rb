module Api
  class ProvisionRequestsController < BaseController
    include Subcollections::RequestTasks
    include Subcollections::Tasks

    def create_resource(type, _id, data)
      assert_id_not_specified(data, type)

      version_str       = data["version"] || "1.1"
      template_fields   = hash_fetch(data, "template_fields")
      vm_fields         = hash_fetch(data, "vm_fields")
      requester         = hash_fetch(data, "requester")
      tags              = hash_fetch(data, "tags")
      additional_values = hash_fetch(data, "additional_values")
      ems_custom_attrs  = hash_fetch(data, "ems_custom_attributes")
      miq_custom_attrs  = hash_fetch(data, "miq_custom_attributes")

      MiqProvisionVirtWorkflow.from_ws(version_str, User.current_user, template_fields, vm_fields, requester, tags,
                                       additional_values, ems_custom_attrs, miq_custom_attrs)
    end

    def deny_resource(type, id, data)
      api_action(type, id) do |klass|
        provreq = resource_search(id, type, klass)
        provreq.deny(@auth_user, data['reason'])
        action_result(true, "Provision request #{id} denied")
      end
    rescue => err
      action_result(false, err.to_s)
    end

    def approve_resource(type, id, data)
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
