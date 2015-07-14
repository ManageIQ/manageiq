class Container < ActiveRecord::Base
  include ReportableMixin
  include NewWithTypeStiMixin

  has_one    :container_group, :through => :container_definition
  delegate   :ext_management_system, :to => :container_group
  delegate   :container_project, :to => :container_group
  belongs_to :container_definition
  belongs_to :container_image
  delegate   :container_image_registry, :to => :container_image
end
