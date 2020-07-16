class ContainerService < ApplicationRecord
  include CustomAttributeMixin
  include SupportsFeatureMixin
  # :name, :uid, :creation_timestamp, :resource_version, :namespace
  # :labels, :selector, :protocol, :port, :container_port, :portal_ip, :session_affinity

  belongs_to  :ext_management_system, :foreign_key => "ems_id"
  has_and_belongs_to_many :container_groups, :join_table => :container_groups_container_services
  has_many :container_routes
  has_many :container_service_port_configs, :dependent => :destroy
  belongs_to :container_project
  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy
  has_many :selector_parts, -> { where(:section => "selectors") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy
  has_many :container_nodes, -> { distinct }, :through => :container_groups
  belongs_to :container_image_registry

  # Needed for metrics
  has_many :metrics,                :as => :resource
  has_many :metric_rollups,         :as => :resource
  has_many :vim_performance_states, :as => :resource
  delegate :my_zone,                :to => :ext_management_system

  acts_as_miq_taggable

  virtual_column :container_groups_count, :type => :integer

  def container_groups_count
    number_of(:container_groups)
  end

  include Metric::CiMixin

  PERF_ROLLUP_CHILDREN = [:container_groups]

  def perf_rollup_parents(interval_name = nil)
    []
  end
end
