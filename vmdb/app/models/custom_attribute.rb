class CustomAttribute < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true

  include ReportableMixin
end
