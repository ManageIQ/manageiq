class ApiController
  INVALID_GROUP_ATTRS = %w(id href group_type)

  module Groups
    def create_resource_groups(_type, _id, data)
      validate_group_data(data)
      parse_set_role(data)
      parse_set_tenant(data)
      parse_set_filters(data)
      group = collection_class(:groups).create(data)
      if group.invalid?
        raise BadRequestError, "Failed to add a new group - #{group.errors.full_messages.join(', ')}"
      end
      group
    end

    def edit_resource_groups(type, id, data)
      validate_group_data(data)
      parse_set_role(data)
      parse_set_tenant(data)
      group = resource_search(id, type, collection_class(:groups))
      parse_set_filters(data, :entitlement_id => group.entitlement.try(:id))
      raise BadRequestError, "Cannot edit a read-only group" if group.read_only
      edit_resource(type, id, data)
    end

    private

    def parse_set_role(data)
      role = parse_fetch_role(data.delete("role"))
      data.merge!("miq_user_role" => role) if role
    end

    def parse_set_tenant(data)
      tenant = parse_fetch_tenant(data.delete("tenant"))
      data.merge!("tenant" => tenant) if tenant
    end

    # HACK: Format attrs to use accepts_nested_attributes_for (Entitlements)
    # Required for backwards compatibility of creating filters via group
    def parse_set_filters(data, entitlement_id: nil)
      filters = data.delete("filters")
      data.merge!("entitlement_attributes" => {"id" => entitlement_id, "filters" => filters}) if filters
    end

    def group_data_includes_invalid_attrs(data)
      data.keys.select { |k| INVALID_GROUP_ATTRS.include?(k) }.compact.join(", ") if data
    end

    def validate_group_data(data)
      bad_attrs = group_data_includes_invalid_attrs(data)
      raise BadRequestError, "Invalid attribute(s) #{bad_attrs} specified for a group" if bad_attrs.present?
      raise BadRequestError, "Invalid filters specified" unless Entitlement.valid_filters?(data["filters"])
    end
  end
end
