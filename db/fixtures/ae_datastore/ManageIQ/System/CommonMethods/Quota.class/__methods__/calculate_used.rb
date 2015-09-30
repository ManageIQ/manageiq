#
# Description: calculate entity used quota values
#

def consumption(entity)
  {
    :cpu                 => entity.allocated_vcpu,
    :memory              => entity.allocated_memory / 1024**2,
    :vms                 => entity.vms.count { |vm| vm.id unless vm.archived },
    :allocated_storage   => entity.allocated_storage / 1024**2,
    :provisioned_storage => entity.provisioned_storage / 1024**2
  }
end

$evm.root['quota_used'] = consumption($evm.root['quota_entity']) if $evm.root['quota_entity']

$evm.log("info", "XXXXXXXXX Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")
