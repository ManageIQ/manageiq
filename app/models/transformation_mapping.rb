class TransformationMapping < ApplicationRecord
  require_nested :VmMigrationValidator

  has_many :transformation_mapping_items, :dependent => :destroy
  has_many :service_resources, :as => :resource, :dependent => :nullify
  has_many :service_templates, :through => :service_resources

  validates :name, :presence => true, :uniqueness => true

  VALID_SOURCE_CLUSTER_TYPES = %w[
    ManageIQ::Providers::Vmware::InfraManager
  ]

  def destination(source)
    transformation_mapping_items.find_by(:source => source).try(:destination)
  end

  # vm_list: collection of hashes, each descriping a VM.
  def search_vms_and_validate(vm_list = nil, service_template_id = nil)
    VmMigrationValidator.new(self, vm_list, service_template_id).validate
  end

  # Return the source cluster for the TransformationMapping, if any.
  #
  def source_cluster
    transformation_mapping_items.find_by(:source_type => 'EmsCluster')&.source
  end

  # Return a list of source datastores associated with the TransformationMapping, if any.
  #
  def source_datastores
    transformation_mapping_items.where(:source_type => 'Storage').map(&:source)
  end

  # Return a list of source networks associated with the TransformationMapping, if any.
  #
  def source_networks
    transformation_mapping_items.where(:source_type => 'Lan').map(&:source)
  end

  # Return the target cluster for the TransformationMapping, if any.
  #
  def destination_cluster
    transformation_mapping_items.find_by(:destination_type => ['EmsCluster', 'CloudTenant'])&.destination
  end

  # Return a list of target datastores associated with the TransformationMapping, if any.
  #
  def destination_datastores
    transformation_mapping_items.where(:destination_type => 'Storage').map(&:source)
  end

  # Return a list of target networks associated with the TransformationMapping, if any.
  #
  def destination_networks
    transformation_mapping_items.where(:destination_type => 'Lan').map(&:source)
  end
end