class ContainerImageRegistry < ActiveRecord::Base
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :container_images, :dependent => :destroy # What about deleted registry but containers are still running
  has_many :containers, :through => :container_images

  acts_as_miq_taggable
end
