class ContainerGroup < ActiveRecord::Base
  include CustomAttributeMixin
  include ReportableMixin
  include NewWithTypeStiMixin

  # :name, :uid, :creation_timestamp, :resource_version, :namespace
  # :labels, :restart_policy, :dns_policy

  has_many :containers, :dependent => :destroy
  has_many :container_definitions, :dependent => :destroy
  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_many :labels, :class_name => CustomAttribute, :as => :resource, :conditions => {:section => "labels"}
  belongs_to :container_node
  has_and_belongs_to_many :container_services
  belongs_to :container_replicator

  # validates :restart_policy, :inclusion => { :in => %w(always onFailure never) }
  # validates :dns_policy, :inclusion => { :in => %w(ClusterFirst Default) }

  include EventMixin

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events
      # TODO: improve relationship using the id
      ["container_namespace = ? AND container_group_name = ? AND ems_id = ?",
       namespace, name, ems_id]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["ems_id = ?", ems_id]
    end
  end

  # Metrics destroy is handled by purger
  has_many :metrics, :as => :resource
  has_many :metric_rollups, :as => :resource
  has_many :vim_performance_states, :as => :resource

  include Metric::CiMixin

  PERF_ROLLUP_CHILDREN = nil

  acts_as_miq_taggable

  delegate :my_zone, :to => :ext_management_system

  def perf_rollup_parent(_interval_name = nil)
    # No rollups: group performance are collected separately
  end
end
