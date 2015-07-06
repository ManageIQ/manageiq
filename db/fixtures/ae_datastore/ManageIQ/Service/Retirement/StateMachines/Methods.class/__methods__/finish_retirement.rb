#
# Description: This method marks the service as retired
#

service = $evm.root['service']
service.finish_retirement if service
