class StorageMetricsMetadata < ApplicationRecord
  serialize :counter_info
  validates_uniqueness_of :type
end
