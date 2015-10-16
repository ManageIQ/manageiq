#
# Description: get quota source.
#

@miq_request = $evm.root['miq_request']
$evm.log(:info, "Request: #{@miq_request.description} id: #{@miq_request.id} ")

$evm.root['quota_source'] = @miq_request.tenant
$evm.root['quota_source_type'] = 'tenant'
$evm.log(:info, "Setting Tenant as Quota Source #{$evm.root['quota_source'].inspect}")
