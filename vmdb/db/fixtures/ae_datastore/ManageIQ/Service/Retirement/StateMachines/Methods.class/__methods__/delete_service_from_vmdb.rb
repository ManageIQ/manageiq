#
# Description: This method removes the Service from the VMDB database
#

service = $evm.root['service']

if service
  $evm.log('info', "Deleting Service <#{service.name}> from VMDB")
  service.remove_from_vmdb
end
