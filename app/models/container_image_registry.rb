class ContainerImageRegistry < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :container_images, :dependent => :destroy # What about deleted registry but containers are still running
  has_many :containers, :through => :container_images
  has_many :container_services
  has_many :container_groups, :through => :container_services

  acts_as_miq_taggable
  virtual_column :full_name, :type => :string

  def full_name
    port.present? ? "#{host}:#{port}" : host
  end
end
