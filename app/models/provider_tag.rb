class ProviderTag < ApplicationRecord
  validates_presence_of :key
  validates_presence_of :resource_id
  validates_presence_of :type
  validates_uniqueness_of :key, :scope => [:value, :resource_id]
end
