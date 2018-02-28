class VmRetireTask < MiqRetireTask
  alias_attribute :vm, :source

  def self.base_model
    VmRetireTask
  end

  def self.model_being_retired
    Vm
  end
end
