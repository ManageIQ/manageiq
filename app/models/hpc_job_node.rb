class HpcJobNode < ApplicationRecord
  belongs_to :hpc_job
  belongs_to :hpc_node
end
