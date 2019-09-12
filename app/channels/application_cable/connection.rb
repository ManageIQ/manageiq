module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    protected

    def find_verified_user
      return reject_unauthorized_connection unless cookies[:ws_token]
      userid = TokenManager.new('ws').token_get_info(cookies[:ws_token], :userid)
      if current_user = User.find_by(:userid => userid.presence)
        current_user
      else
        reject_unauthorized_connection
      end
    end
  end
end
