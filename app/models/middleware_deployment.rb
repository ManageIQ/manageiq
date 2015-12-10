class MiddlewareDeployment < ActiveRecord::Base
  include ReportableMixin

  belongs_to :middleware_server, :foreign_key => "server_id"
  acts_as_miq_taggable
end
