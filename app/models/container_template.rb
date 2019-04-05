class ContainerTemplate < ApplicationRecord
  include CustomAttributeMixin
  include CustomActionsMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_project
  has_many :container_template_parameters, :dependent => :destroy
  has_many :labels, -> { where(:section => "labels") },
           :class_name => "CustomAttribute",
           :as         => :resource,
           :dependent  => :destroy

  serialize :objects, Array
  serialize :object_labels, Hash

  acts_as_miq_taggable
end
