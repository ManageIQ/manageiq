#
# Description: Set Tenant as the default quota source.
#

# Sample code to enable group as the default quota source.
# $evm.root['quota_source'] = @miq_request.requester.current_group
# $evm.root['quota_source_type'] = 'group'

@miq_request = $evm.root['miq_request']
$evm.log(:info, "Request: #{@miq_request.description} id: #{@miq_request.id} ")

$evm.root['quota_source'] = @miq_request.tenant
$evm.root['quota_source_type'] = 'tenant'

$evm.log(:info, "Setting Quota Source #{$evm.root['quota_source'].inspect}")
