class Switch < ApplicationRecord
  include NewWithTypeStiMixin
  include CustomActionsMixin
  extend TenancyCommonMixin

  belongs_to :host, :inverse_of => :host_virtual_switches
  has_one :ext_management_system, :through => :host

  has_many :host_switches, :dependent => :destroy
  has_many :hosts, :through => :host_switches

  has_many :guest_devices
  has_many :lans, :dependent => :destroy
  has_many :subnets, :through => :lans

  scope :shareable, ->     { where(:shared => true) }
  scope :with_id,   ->(id) { where(:id => id) }

  has_one :tenant, :through => :ext_management_system

  def self.scope_by_tenant?
    true
  end

  def self.tenant_id_clause_format(tenant_ids)
    {:ext_management_systems => {:tenant_id => tenant_ids}}
  end

  # in a perfect world, all of this would be in tenant_clause
  # and that would not return a hash but a scope
  def self.tenant_join_clause
    left_outer_joins(:tenant)
  end

  acts_as_miq_taggable
end
