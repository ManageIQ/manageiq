class ContainerProject < ActiveRecord::Base
  include CustomAttributeMixin
  include ReportableMixin
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups
  has_many :container_routes
  has_many :container_replicators
  has_many :container_services
  has_many :container_definitions, :through => :container_groups

  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy

  virtual_column :groups_count,      :type => :integer
  virtual_column :services_count,    :type => :integer
  virtual_column :routes_count,      :type => :integer
  virtual_column :replicators_count, :type => :integer
  virtual_column :containers_count,  :type => :integer

  def groups_count
    container_groups.size
  end

  def routes_count
    container_routes.size
  end

  def replicators_count
    container_replicators.size
  end

  def services_count
    container_services.size
  end

  def containers_count
    container_definitions.size
  end

  acts_as_miq_taggable
end
