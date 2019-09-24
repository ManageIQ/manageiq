class ContainerImageRegistry < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"

  # Associated with images in the registry.
  has_many :container_images, :dependent => :nullify
  has_many :containers, :through => :container_images
  has_many :container_groups, :through => :container_images

  # Associated with serving the registry itself - for openshift's internal
  # image registry. These will be empty for external registries.
  has_many :container_services
  has_many :service_container_groups, :through => :container_services, :as => :container_groups

  acts_as_miq_taggable
  virtual_column :full_name, :type => :string

  def full_name
    port.present? ? "#{host}:#{port}" : host
  end
end
