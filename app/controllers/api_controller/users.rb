class ApiController
  module Users
    def update_users
      aname = parse_action_name
      if aname == "edit" && !api_user_role_allows?(aname) && update_target_is_api_user?
        if json_body_resource.try(:keys) != %w(password)
          raise BadRequestError, "Cannot update non-password attributes of the authenticated user resource"
        end
        render_normal_update :users, update_collection(:users, @req[:c_id])
      else
        update_generic(:users)
      end
    end

    private

    def update_target_is_api_user?
      @auth_user_obj.id == @req[:c_id].to_i
    end
  end
end
