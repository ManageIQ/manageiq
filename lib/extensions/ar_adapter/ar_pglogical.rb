require 'ar_pglogical/pglogical_raw'

module PgLogicalAdapterMixin
  def pglogical
    PgLogicalRaw.new(self)
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include PgLogicalAdapterMixin
