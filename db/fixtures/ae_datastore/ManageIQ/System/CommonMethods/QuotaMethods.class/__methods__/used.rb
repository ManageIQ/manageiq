#
# Description: calculate entity used quota values
#
def bytes_to_megabytes(number)
  number / 1024**2
end

def consumption(source)
  {
    :cpu                 => source.allocated_vcpu,
    :memory              => bytes_to_megabytes(source.allocated_memory),
    :vms                 => source.vms.count { |vm| vm.id unless vm.archived },
    :storage             => bytes_to_megabytes(source.allocated_storage),
    :provisioned_storage => bytes_to_megabytes(source.provisioned_storage)
  }
end

$evm.root['quota_used'] = consumption($evm.root['quota_source']) if $evm.root['quota_source']
