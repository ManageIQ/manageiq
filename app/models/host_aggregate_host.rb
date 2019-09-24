class HostAggregateHost < ApplicationRecord
  belongs_to :host
  belongs_to :host_aggregate
end
