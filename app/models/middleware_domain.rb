class MiddlewareDomain < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :middleware_server_groups, :foreign_key => "domain_id", :dependent => :destroy
  serialize :properties
  acts_as_miq_taggable
end
