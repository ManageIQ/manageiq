module ManageIQ::Providers
  class HpcManager < BaseManager
    include SupportsFeatureMixin

    has_many :hpc_queues, -> { active }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :foreign_key => :ems_id,
             :inverse_of  => :ext_management_system
    has_many :hpc_nodes, -> { active }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :foreign_key => :ems_id,
             :inverse_of  => :ext_management_system
    has_many :hpc_jobs, -> { active }, # rubocop:disable Rails/HasManyOrHasOneDependent
             :foreign_key => :ems_id,
             :inverse_of  => :ext_management_system

    # Archived and active entities to destroy when the HPC manager is deleted
    has_many :all_hpc_queues, :foreign_key => :ems_id, :dependent => :destroy, :class_name => "HpcQueue", :inverse_of => false
    has_many :all_hpc_nodes,  :foreign_key => :ems_id, :dependent => :destroy, :class_name => "HpcNode",  :inverse_of => false
    has_many :all_hpc_jobs,   :foreign_key => :ems_id, :dependent => :destroy, :class_name => "HpcJob",   :inverse_of => false

    class << model_name
      define_method(:route_key) { "ems_hpcs" }
      define_method(:singular_route_key) { "ems_hpc" }
    end

    def self.display_name(number = 1)
      n_('HPC Manager', 'HPC Managers', number)
    end
  end
end
