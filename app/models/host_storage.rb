class HostStorage < ActiveRecord::Base
  belongs_to :host
  belongs_to :storage
end
