class ApiController
  module Users
    def update_users
      if target_user_for_update_is_self?
        @req[:action] = "edit"
        render_normal_update :users, update_collection(:users, @req[:c_id])
      else
        update_generic(:users)
      end
    end

    private

    def target_user_for_update_is_self?
      @auth_user_obj.id == @req[:c_id].to_i
    end
  end
end
