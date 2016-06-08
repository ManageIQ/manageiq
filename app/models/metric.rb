class Metric < ApplicationRecord
  BASE_COLS = ['id', 'timestamp', 'capture_interval_name', 'resource_type', 'resource_id', 'resource_name', 'tag_names', 'parent_host_id', 'parent_ems_cluster_id', 'parent_ems_id', 'parent_storage_id']

  include Metric::Common
end
