# Note on the database layout of `metrics` and `metrics_rollups`
#
# In the database, the `metrics` table leverages [PostgreSQL table inheritance]
# and [PostgreSQL table partioning].
#
# Table inheritance is used to create child tables with the same structure as
# the parent.  As columns are added or removed from the parent table, they are
# automatically added and removed from the child tables.  The `metrics` table,
# which is used for "realtime" data, has 24 child tables, one per hour.  The
# `metrics_rollups` table, which is used for long term "rollup" data, has 12
# child tables, one per month.
#
# Table partitioning is used to divert inserts and deletes from the parent table
# to a specific child table, and to allow queries to search across the various
# child tables and return the results as if they were in a single table.  This
# is accomplished using triggers on the parent table, which look at the hour of
# the timestamp for `metrics` or the month of the timestamp for
# `metric_rollups`, and then diverting to the corresponding child table.
# Additionally, a shared sequence is used from the parent table for the primary
# key, so that when queries blend the rows together the primary key constraint
# is satisfied.
#
# The reason for all of this is because of read/write contention.  The metrics
# table is mostly an append-only table, so writes happen at the end of data.
# Purges on the other hand, happen on record at the beginning of the table.
# Additonally, the purge time frame causes those deletes to be very far away
# from the inserts.  When all of the records are in a single table, these
# deletes from purges have a negative performance effect on inserts.  However,
# putting the records into separate tables allows inserts to occur in one table,
# while deletes occur in a completely different table, eliminating the
# read/write contention.
#
# [PostgreSQL table inheritance]: https://www.postgresql.org/docs/9.6/static/tutorial-inheritance.html
# [PostgreSQL table partioning]: https://www.postgresql.org/docs/9.6/static/ddl-partitioning.html
class Metric < ApplicationRecord
  # Specify the primary key for a model backed by a view
  self.primary_key = "id"

  BASE_COLS = ["id", "timestamp", "capture_interval_name", "resource_type", "resource_id", "resource_name", "tag_names", "parent_host_id", "parent_ems_cluster_id", "parent_ems_id", "parent_storage_id"]

  include Metric::Common

  # @param time [ActiveSupport::TimeWithZone, Time, Integer, nil] the hour to run (default: 1 hour from now)
  # @return the table for the given hour
  # Unfortunatly, Integer responds_to :hour, so :strftime was used instead.
  def self.reindex_table_name(time = Time.now.utc.hour + 1)
    hour = (time.respond_to?(:strftime) ? time.hour : time) % 24
    "metrics_%02d" % hour
  end
end
