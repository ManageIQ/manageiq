class FirmwareBinary < ApplicationRecord
  validates :name, :presence => true
  has_many :endpoints, :dependent => :destroy, :as => :resource, :inverse_of => :resource
  has_many :firmware_binary_firmware_targets, :dependent => :destroy
  has_many :firmware_targets, :through => :firmware_binary_firmware_targets
  belongs_to :firmware_registry

  def allow_duplicate_endpoint_url?
    true
  end

  def urls
    endpoints.loaded? ? endpoints.map(&:url) : endpoints.pluck(:url)
  end
end
