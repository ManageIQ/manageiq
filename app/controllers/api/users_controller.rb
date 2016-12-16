module Api
  class UsersController < BaseController
    INVALID_USER_ATTRS = %w(id href current_group_id settings).freeze # Cannot update other people's settings
    INVALID_SELF_USER_ATTRS = %w(id href current_group_id).freeze

    include Subcollections::Tags

    skip_before_action :validate_api_action, :only => :update

    def update
      aname = @req.action
      if aname == "edit" && !api_user_role_allows?(aname) && update_target_is_api_user?
        editable_attrs = %w(password email settings)
        if (Array(json_body_resource.try(:keys)) - editable_attrs).present?
          raise BadRequestError,
                "Cannot update attributes other than #{editable_attrs.join(', ')} for the authenticated user"
        end
        render_normal_update :users, update_collection(:users, @req.c_id)
      else
        validate_api_action
        super
      end
    end

    def create_resource(_type, _id, data)
      validate_user_create_data(data)
      parse_set_group(data)
      raise BadRequestError, "Must specify a valid group for creating a user" unless data["miq_groups"]
      parse_set_settings(data)
      user = collection_class(:users).create(data)
      if user.invalid?
        raise BadRequestError, "Failed to add a new user - #{user.errors.full_messages.join(', ')}"
      end
      user
    end

    def edit_resource(type, id, data)
      (id == User.current_user.id) ? validate_self_user_data(data) : validate_user_data(data)
      parse_set_group(data)
      parse_set_settings(data, resource_search(id, type, collection_class(type)))
      super
    end

    def delete_resource(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for deleting a user" unless id
      raise BadRequestError, "Cannot delete user of current request" if id.to_i == User.current_user.id
      super
    end

    private

    def update_target_is_api_user?
      User.current_user.id == @req.c_id.to_i
    end

    def parse_set_group(data)
      group = parse_fetch_group(data.delete("group"))
      data.merge!("miq_groups" => Array(group)) if group
    end

    def parse_set_settings(data, user = nil)
      settings = data.delete("settings")
      if settings.present?
        current_settings = user.nil? ? {} : user.settings
        data.merge!("settings" => Hash(current_settings).deep_merge(settings.deep_symbolize_keys))
      end
    end

    def validate_user_data(data = {})
      bad_attrs = data.keys.select { |k| INVALID_USER_ATTRS.include?(k) }.compact.join(", ")
      raise BadRequestError, "Invalid attribute(s) #{bad_attrs} specified for a user" if bad_attrs.present?
    end

    def validate_self_user_data(data = {})
      bad_attrs = data.keys.select { |k| INVALID_SELF_USER_ATTRS.include?(k) }.compact.join(", ")
      raise BadRequestError, "Invalid attribute(s) #{bad_attrs} specified for the current user" if bad_attrs.present?
    end

    def validate_user_create_data(data)
      validate_user_data(data)
      req_attrs = %w(name userid group)
      req_attrs << "password" if ::Settings.authentication.mode == "database"
      bad_attrs = []
      req_attrs.each { |attr| bad_attrs << attr if data[attr].blank? }
      raise BadRequestError, "Missing attribute(s) #{bad_attrs.join(', ')} for creating a user" if bad_attrs.present?
    end
  end
end
