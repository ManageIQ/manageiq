class ProviderTag < ApplicationRecord
  validates :key, :presence => true
  validates :resource_id, :presence => true
  validates :type, :presence => true
  validates :key, :uniqueness => { :scope => [:value, :resource_id] }
end
