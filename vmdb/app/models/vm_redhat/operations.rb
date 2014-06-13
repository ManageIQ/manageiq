module VmRedhat::Operations
  include_concern 'Guest'
  include_concern 'Power'

  def raw_destroy
    with_provider_object { |rhevm_vm| rhevm_vm.destroy }
  end
end
