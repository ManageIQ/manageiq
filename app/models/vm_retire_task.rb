class VmRetireTask < MiqRetireTask
  alias_attribute :vm, :source
  attribute :request_type, :default => "vm_retire"

  def self.base_model
    VmRetireTask
  end

  def self.model_being_retired
    Vm
  end
end
