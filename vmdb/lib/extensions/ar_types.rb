ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
  prepend Module.new {
    def initialize_type_map(m)
      super
      m.alias_type 'xid', 'varchar'
    end
  }
end
