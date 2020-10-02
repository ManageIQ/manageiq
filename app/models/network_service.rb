class NetworkService < ApplicationRecord
  include NewWithTypeStiMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack

  has_many :network_service_entries, :foreign_key => :network_service_id, :dependent => :destroy
  alias entries network_service_entries

  has_many :security_policy_rule_network_services, :dependent => :destroy
  has_many :security_policy_rules, :through => :security_policy_rule_network_services

  virtual_total :entries_count, :network_service_entries
  virtual_total :security_policy_rules_count, :security_policy_rules

  def self.class_by_ems(ext_management_system)
    # TODO: use a factory on ExtManagementSystem side to return correct class for each provider
    ext_management_system && ext_management_system.class::NetworkService
  end

  def self.display_name(number = 1)
    n_('Network Service', 'Network Services', number)
  end
end
