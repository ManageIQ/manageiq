class HostsStorage < ApplicationRecord
  self.table_name = "host_storages"
  belongs_to :host
  belongs_to :storage
end
