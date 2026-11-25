class HpcQueueNode < ApplicationRecord
  belongs_to :hpc_queue
  belongs_to :hpc_node
end
