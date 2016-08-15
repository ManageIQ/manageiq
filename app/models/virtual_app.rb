class VirtualApp < ResourcePool
  has_many :lan_virtual_apps
  has_many :lans, :through => :lan_virtual_apps
end
