class VmServer < Vm
  default_scope :conditions => ["vdi = ?", false]
end
