class ContainerBuildPod < ApplicationRecord
  include CustomAttributeMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_build

  has_many :labels, -> { where(:section => "labels") },
           :class_name => "CustomAttribute",
           :as         => :resource,
           :dependent  => :destroy

  has_one :container_group
end
