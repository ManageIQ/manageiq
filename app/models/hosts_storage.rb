class HostsStorage < ActiveRecord::Base
  belongs_to :host
  belongs_to :storage
end
