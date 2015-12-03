class MiddlewareServer < ActiveRecord::Base
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  acts_as_miq_taggable
end
