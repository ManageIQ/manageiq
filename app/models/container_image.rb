class ContainerImage < ActiveRecord::Base
  include ReportableMixin

  belongs_to :container_image_registry
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :containers

  acts_as_miq_taggable

  def full_name
    result = ""
    result << "#{container_image_registry.full_name}/" unless container_image_registry.nil?
    result << name
    result << ":#{tag}" unless tag.nil?
    result
  end

  def scan
    raise 'Feature not implemented'
  end
end
