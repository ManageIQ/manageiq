class VmdbDatabaseMetric < ActiveRecord::Base
  belongs_to :vmdb_database

  VmdbMetric # Eager load VmdbMetric class to allow access to VmdbMetric::Purging
  include_concern 'VmdbMetric::Purging'
  include ReportableMixin
end
