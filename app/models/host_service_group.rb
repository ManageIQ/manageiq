class HostServiceGroup < ApplicationRecord
  has_many :filesystems, :dependent => :nullify
  has_many :system_services, :dependent => :nullify
  belongs_to :host
end

DescendantLoader.instance.load_subclasses(HostServiceGroup)
