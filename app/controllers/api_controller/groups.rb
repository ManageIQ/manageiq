class ApiController
  INVALID_GROUP_ATTRS = %w(id href group_type)

  module Groups
    def create_resource_groups(_type, _id, data)
      validate_data(data)
      parse_set_role(data)
      parse_set_tenant(data)
      group = collection_class(:groups).create(data)
      if group.invalid?
        raise BadRequestError, "Failed to add a new group - #{group.errors.full_messages.join(', ')}"
      end
      group
    end

    def edit_resource_groups(type, id, data)
      validate_data(data)
      parse_set_role(data)
      parse_set_tenant(data)
      group = resource_search(id, type, collection_class(:groups))
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

    def data_includes_invalid_attrs(data)
      data.keys.select { |k| INVALID_GROUP_ATTRS.include?(k) }.compact.join(", ") if data
    end

    def validate_data(data)
      klass = collection_class(:groups)
      bad_attrs = data_includes_invalid_attrs(data)
      raise BadRequestError, "Invalid attribute(s) #{bad_attrs} specified for a group" if bad_attrs.present?
      raise BadRequestError, "Invalid filters specified" unless klass.valid_filters?(data["filters"])
    end
  end
end
