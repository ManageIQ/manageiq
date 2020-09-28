class TokenStore
  class SqlStore
    def initialize(options)
      @namespace = options.fetch(:namespace)
    end

    def create_user_token(token, data, options)
      write(token, data, options)
    end

    def write(token, data, _options = nil)
      record = Session.find_or_create_by(:session_id => session_key(token))
      record.raw_data = data
      record.user_id = find_user_by_userid(data[:userid]).try(:id) if data[:userid]
      record.save!
    end

    def read(token, _options = nil)
      record = Session.find_by(:session_id => session_key(token))
      return nil unless record
      data = record.raw_data
      if data[:expires_on] > Time.zone.now
        data
      else
        record.destroy
        nil
      end
    end

    def delete(token)
      record = Session.find_by(:session_id => session_key(token))
      return nil unless record
      record.destroy!
    end

    def delete_all_for_user(userid)
      user = find_user_by_userid(userid)
      user.sessions.where(Session.arel_table[:session_id].matches("#{@namespace}%", nil, true)).destroy_all
    end

    private

    attr_reader :namespace

    def session_key(token)
      "#{namespace}:#{token}"
    end

    def find_user_by_userid(userid)
      User.in_my_region.where('lower(userid) = ?', userid.downcase).first
    end

    def find_user_by_id(id)
      User.in_my_region.where(:id => id).first
    end
  end
end
