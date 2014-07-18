class ApiController
  module ProvisionRequests
    def create_resource_provision_requests(type, _id, data)
      if data.key?("id") || data.key?("href")
        raise BadRequestError,
              "Resource id or href should not be specified for creating a new #{type}"
      end

      version_str       = data["version"] || "1.1"
      template_fields   = hash_fetch(data, "template_fields")
      vm_fields         = hash_fetch(data, "vm_fields")
      requester         = hash_fetch(data, "requester")
      tags              = hash_fetch(data, "tags")
      additional_values = hash_fetch(data, "additional_values")
      ems_custom_attrs  = hash_fetch(data, "ems_custom_attributes")
      miq_custom_attrs  = hash_fetch(data, "miq_custom_attributes")

      user_name = requester["user_name"] || @auth_user

      MiqProvisionWorkflow.from_ws(version_str, user_name, template_fields, vm_fields, requester, tags,
                                   additional_values, ems_custom_attrs, miq_custom_attrs)
    end
  end
end
