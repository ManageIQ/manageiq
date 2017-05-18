class MiddlewareServerGroup < ApplicationRecord
  belongs_to :middleware_domain, :foreign_key => "domain_id"
  has_many :middleware_servers, :foreign_key => "server_group_id", :dependent => :destroy
  has_many :middleware_deployments, :foreign_key => "server_group_id", :dependent => :destroy
  serialize :properties
  acts_as_miq_taggable

  delegate :ext_management_system, :to => :middleware_domain, :allow_nil => true
end
