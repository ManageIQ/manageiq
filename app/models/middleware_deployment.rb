class MiddlewareDeployment < ApplicationRecord
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :middleware_server, :foreign_key => "server_id"
  belongs_to :middleware_server_group, :foreign_key => "server_group_id", :optional => true
  acts_as_miq_taggable

  delegate :mutable?, :in_domain?, :to => :middleware_server
end
