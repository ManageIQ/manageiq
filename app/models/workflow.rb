class Workflow < ApplicationRecord
  include NewWithTypeStiMixin
  include TenancyMixin

  belongs_to :ext_management_system, :inverse_of => :workflows, :class_name => "ManageIQ::Providers::AutomationManager", :foreign_key => :ems_id
  belongs_to :tenant

  has_many :workflow_instances, :dependent => :destroy

  def self.create_from_json!(json)
    json = JSON.parse(json) if json.kind_of?(String)
    name = json["Comment"]

    create!(:name => name, :payload => json)
  end
end
