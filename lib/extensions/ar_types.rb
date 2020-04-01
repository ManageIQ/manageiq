require 'active_record/connection_adapters/postgresql_adapter'
ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
  prepend Module.new {
    def initialize_type_map(m = type_map)
      super
      m.alias_type('xid', 'varchar')
    end
  }
end
