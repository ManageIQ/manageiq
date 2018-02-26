class Metric < ApplicationRecord
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
