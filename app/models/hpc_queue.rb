class HpcQueue < ApplicationRecord
  self.table_name = "hpc_queues"

  acts_as_miq_taggable

  include SupportsFeatureMixin
  include TenantIdentityMixin
  include ArchivedMixin
  include Purging

  belongs_to :ext_management_system, :foreign_key => "ems_id", :inverse_of => false

  has_many :hpc_queue_nodes, :dependent => :destroy
  has_many :hpc_nodes, :through => :hpc_queue_nodes

  has_many :hpc_jobs, -> { active }, :inverse_of => :hpc_queue # rubocop:disable Rails/HasManyOrHasOneDependent
  has_many :all_hpc_jobs, :class_name => "HpcJob", :inverse_of => :hpc_queue, :dependent => :nullify

  def disconnect_inv
    return if archived?

    _log.info("Disconnecting HPC Queue [#{name}] id [#{id}] from EMS [#{ext_management_system&.name}] id [#{ext_management_system&.id}]")
    self.deleted_on = Time.now.utc
    save
  end
end
