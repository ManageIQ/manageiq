class EvmDatabaseOps
  def self.database_connections(database = nil, _type = :all)
    database ||= ActiveRecord::Base.configurations[Rails.env]["database"]
    conn = ActiveRecord::Base.connection
    conn.client_connections.count { |c| c["database"] == database }
  end
end
