class ContainerTemplate < ApplicationRecord
  include CustomAttributeMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :container_project
  has_many :container_template_parameters, :dependent => :destroy
  has_many :labels, -> { where(:section => "labels") },
           :class_name => CustomAttribute,
           :as         => :resource,
           :dependent  => :destroy

  serialize :objects, Array

  acts_as_miq_taggable
end
