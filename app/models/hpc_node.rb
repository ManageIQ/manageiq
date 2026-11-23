class HpcNode < ApplicationRecord
  acts_as_miq_taggable

  include SupportsFeatureMixin
  include TenantIdentityMixin
  include ArchivedMixin
  include Purging

  belongs_to :ext_management_system, :foreign_key => "ems_id", :inverse_of => false
  belongs_to :lives_on, :polymorphic => true, :optional => true

  has_many :hpc_queue_nodes, :dependent => :destroy
  has_many :hpc_queues, :through => :hpc_queue_nodes

  has_many :hpc_job_nodes, :dependent => :destroy
  has_many :hpc_jobs, :through => :hpc_job_nodes

  def disconnect_inv
    return if archived?

    _log.info("Disconnecting HPC Node [#{name}] id [#{id}] from EMS [#{ext_management_system&.name}] id [#{ext_management_system&.id}]")
    self.deleted_on = Time.now.utc
    save
  end
end
