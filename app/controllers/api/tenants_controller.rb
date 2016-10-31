module Api
  class TenantsController < BaseController
    INVALID_TENANT_ATTRS = %w(id href ancestry).freeze

    include Subcollections::Tags
    include Subcollections::Quotas

    def create_resource(_type, _id, data)
      bad_attrs = data_includes_invalid_attrs(data)
      if bad_attrs.present?
        raise BadRequestError,
              "Attribute(s) #{bad_attrs} should not be specified for creating a new tenant resource"
      end
      parse_set_parent(data)
      tenant = Tenant.create(data)
      if tenant.invalid?
        raise BadRequestError, "Failed to add a new tenant resource - #{tenant.errors.full_messages.join(', ')}"
      end
      tenant
    end

    def edit_resource(type, id, data)
      bad_attrs = data_includes_invalid_attrs(data)
      if bad_attrs.present?
        raise BadRequestError, "Attributes #{bad_attrs} should not be specified for updating a tenant resource"
      end
      parse_set_parent(data)
      super
    end

    private

    def parse_set_parent(data)
      parent = parse_fetch_tenant(data.delete("parent"))
      data.merge!("parent" => parent) if parent
    end

    def data_includes_invalid_attrs(data)
      data.keys.select { |k| INVALID_TENANT_ATTRS.include?(k) }.compact.join(", ") if data
    end
  end
end
