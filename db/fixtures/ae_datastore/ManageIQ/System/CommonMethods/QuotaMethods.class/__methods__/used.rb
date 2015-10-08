#
# Description: calculate entity used quota values
#

def consumption(source)
  {
    :cpu                 => source.allocated_vcpu,
    :memory              => source.allocated_memory / 1024**2,
    :vms                 => source.vms.count { |vm| vm.id unless vm.archived },
    :storage             => source.allocated_storage / 1024**2,
    :provisioned_storage => source.provisioned_storage / 1024**2
  }
end

$evm.root['quota_used'] = consumption($evm.root['quota_source']) if $evm.root['quota_source']
