class VmdbDatabaseMetric < ApplicationRecord
  belongs_to :vmdb_database

  VmdbMetric # Eager load VmdbMetric class to allow access to VmdbMetric::Purging
  include_concern 'VmdbMetric::Purging'

  def self.display_name(number = 1)
    n_('Database Metric', 'Database Metrics', number)
  end
end
