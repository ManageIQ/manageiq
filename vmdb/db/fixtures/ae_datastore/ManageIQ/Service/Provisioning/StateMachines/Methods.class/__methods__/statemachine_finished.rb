#
# Description: Set finished message for provision object.
#

prov = $evm.root['service_template_provision_task']
prov.finished('Service Provisioned Successfully')
