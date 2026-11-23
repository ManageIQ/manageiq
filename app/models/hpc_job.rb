class HpcJob < ApplicationRecord
  acts_as_miq_taggable

  include SupportsFeatureMixin
  include TenantIdentityMixin
  include ArchivedMixin
  include Purging

  belongs_to :ext_management_system, :foreign_key => "ems_id", :inverse_of => false
  belongs_to :hpc_queue, :optional => true

  has_many :hpc_job_nodes, :dependent => :destroy
  has_many :hpc_nodes, :through => :hpc_job_nodes

  def disconnect_inv
    return if archived?

    _log.info("Disconnecting HPC Job [#{name}] id [#{id}] from EMS [#{ext_management_system&.name}] id [#{ext_management_system&.id}]")
    self.deleted_on = Time.now.utc
    save
  end
end
