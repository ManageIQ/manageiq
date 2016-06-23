class ApiController
  INVALID_USER_ATTRS = %w(id href current_group_id)

  module Users
    def update_users
      aname = @req.action
      if aname == "edit" && !api_user_role_allows?(aname) && update_target_is_api_user?
        if json_body_resource.try(:keys) != %w(password)
          raise BadRequestError, "Cannot update non-password attributes of the authenticated user resource"
        end
        render_normal_update :users, update_collection(:users, @req.c_id)
      else
        update_generic(:users)
      end
    end

    def create_resource_users(_type, _id, data)
      validate_user_create_data(data)
      parse_set_group(data)
      raise BadRequestError, "Must specify a valid group for creating a user" unless data["miq_groups"]
      user = collection_class(:users).create(data)
      if user.invalid?
        raise BadRequestError, "Failed to add a new user - #{user.errors.full_messages.join(', ')}"
      end
      user
    end

    def edit_resource_users(type, id, data)
      validate_user_data(data)
      parse_set_group(data)
      edit_resource(type, id, data)
    end

    def delete_resource_users(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for deleting a user" unless id
      raise BadRequestError, "Cannot delete user of current request" if id.to_i == @auth_user_obj.id
      delete_resource(type, id, data)
    end

    private

    def update_target_is_api_user?
      @auth_user_obj.id == @req.c_id.to_i
    end

    def parse_set_group(data)
      group = parse_fetch_group(data.delete("group"))
      data.merge!("miq_groups" => Array(group)) if group
    end

    def validate_user_data(data = {})
      bad_attrs = data.keys.select { |k| INVALID_USER_ATTRS.include?(k) }.compact.join(", ")
      raise BadRequestError, "Invalid attribute(s) #{bad_attrs} specified for a user" if bad_attrs.present?
    end

    def validate_user_create_data(data)
      validate_user_data(data)
      req_attrs = %w(name userid group)
      req_attrs << "password" if VMDB::Config.new("vmdb").config.fetch_path(:authentication, :mode) == "database"
      bad_attrs = []
      req_attrs.each { |attr| bad_attrs << attr if data[attr].blank? }
      raise BadRequestError, "Missing attribute(s) #{bad_attrs.join(', ')} for creating a user" if bad_attrs.present?
    end
  end
end
