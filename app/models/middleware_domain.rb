class MiddlewareDomain < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  belongs_to :lives_on, :polymorphic => true
  has_many :middleware_server_group, :foreign_key => "domain_id", :dependent => :destroy
  serialize :properties
end
