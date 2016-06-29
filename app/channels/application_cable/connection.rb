module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    # TODO: what if the user is not logged in
    def connect
      self.current_user = find_verified_user
    end

    protected

    # TODO: Do we need really to enter to the database?
    def find_verified_user
      User.find_by(:userid => userid_from_session)
    end

    # TODO: What if the session store is different?
    def userid_from_session
      cache = Vmdb::Application.config.session_options[:cache]
      servers = cache.instance_variable_get(:@servers)
      options = cache.instance_variable_get(:@options)
      client = Dalli::Client.new(servers, options)
      client.get(cookies['_vmdb_session'])['userid']
    end
  end
end
