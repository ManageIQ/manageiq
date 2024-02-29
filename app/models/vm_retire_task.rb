class VmRetireTask < MiqRetireTask
  alias_attribute :vm, :source
  default_value_for :request_type, "vm_retire"

  def self.base_model
    VmRetireTask
  end

  def self.model_being_retired
    Vm
  end
end
