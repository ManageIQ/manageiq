class ContainerPortConfig < ApplicationRecord
  # :port, :host_port, :protocol
  belongs_to :container_definition
end
