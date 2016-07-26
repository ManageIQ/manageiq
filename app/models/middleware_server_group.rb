class MiddlewareServerGroup < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :middleware_domain, :foreign_key => "domain_id"
  belongs_to :lives_on, :polymorphic => true
  has_many :middleware_server, :foreign_key => "server_group_id", :dependent => :destroy
  serialize :properties
end
