#
# Description: calculate entity used quota values
#

def consumption(source)
  {
    :cpu                 => source.allocated_vcpu,
    :memory              => source.allocated_memory,
    :vms                 => source.vms.count { |vm| vm.id unless vm.archived },
    :storage             => source.allocated_storage,
    :provisioned_storage => source.provisioned_storage
  }
end

$evm.root['quota_used'] = consumption($evm.root['quota_source']) if $evm.root['quota_source']
