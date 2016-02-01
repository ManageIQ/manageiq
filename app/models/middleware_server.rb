class MiddlewareServer < ActiveRecord::Base
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :middleware_deployments, :foreign_key => "server_id", :dependent => :destroy
  serialize :properties
  acts_as_miq_taggable
end
