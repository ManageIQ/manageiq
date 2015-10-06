class ApiController
  module Tenants
    def create_resource_tenants(_type, _id, data)
      if data.key?("id") || data.key?("href")
        raise BadRequestError,
              "Resource id or href should not be specified for creating a new tenant resource"
      end
      parent_data = data.delete("parent")
      parent = fetch_parent(parent_data)
      data.merge!("parent" => parent)
      tenant = Tenant.create(data)
      if tenant.invalid?
        raise BadRequestError, "Failed to add a new tenant resource - #{tenant.errors.full_messages.join(', ')}"
      end
      tenant
    end

    private

    def fetch_parent(data)
      if data.key?("id")
        parent_id = data["id"]
      else
        _, parent_id = parse_href(data["href"])
      end
      Tenant.find_by_id(parent_id)
    end
  end
end
