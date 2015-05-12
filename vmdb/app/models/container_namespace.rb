class ContainerNamespace < ActiveRecord::Base
  include CustomAttributeMixin

  has_many :labels, :class_name => CustomAttribute, :as => :resource, :conditions => {:section => "labels"}
end
