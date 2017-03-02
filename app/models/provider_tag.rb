# The ProviderTag model serves as the class for tags (key/value pairs) that
# exist on remote (e.g. Azure, Amazon) resources. We then store and manage
# them locally.
#
# When establishing a relationship from a model, it should look like this:
#
#   has_many :provider_tags, :foreign_key => :resource_id, :primary_key => :some_unique_key
#
# Where 'some_unique_key' is ems_ref, guid, or whatever stringy key uniquely
# identifies that resource.
#
class ProviderTag < ApplicationRecord
  validates :key, :presence => true
  validates :resource_id, :presence => true
  validates :type, :presence => true
  validates :key, :uniqueness => { :scope => [:value, :resource_id] }
end
