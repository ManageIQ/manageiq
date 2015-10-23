class ApiController
  module AutomationRequests
    def create_resource_automation_requests(type, _id, data)
      if data.key?("id") || data.key?("href")
        raise BadRequestError,
              "Resource id or href should not be specified for creating a new #{type}"
      end

      version_str = data["version"] || "1.1"
      uri_parts   = hash_fetch(data, "uri_parts")
      parameters  = hash_fetch(data, "parameters")
      requester   = hash_fetch(data, "requester")

      AutomationRequest.create_from_ws(version_str, @auth_user_obj, uri_parts, parameters, requester)
    end
  end
end
