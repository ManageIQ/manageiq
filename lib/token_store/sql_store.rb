class TokenStore
  class SqlStore
    def initialize(options)
      @namespace = options.fetch(:namespace)
    end

    def write(token, data, _options = nil)
      record = Session.find_or_create_by(:session_id => session_key(token))
      record.raw_data = data
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

    private

    attr_reader :namespace

    def session_key(token)
      "#{namespace}:#{token}"
    end
  end
end
