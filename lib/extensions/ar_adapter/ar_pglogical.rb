require 'pglogical'

module PgLogicalAdapterMixin
  def pglogical
    PgLogical.new(self)
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include PgLogicalAdapterMixin
