class StorageMetricsMetadata < ActiveRecord::Base
  serialize :counter_info
  validates_uniqueness_of :type
end
