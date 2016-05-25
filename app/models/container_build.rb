class ContainerBuild < ApplicationRecord
  include CustomAttributeMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_project

  has_many :labels, -> { where(:section => "labels") },
           :class_name => "CustomAttribute",
           :as         => :resource,
           :dependent  => :destroy

  has_many :container_build_pods

  acts_as_miq_taggable
end
