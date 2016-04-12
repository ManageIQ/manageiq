#
# Description: Get quota source.
#

@miq_request = $evm.root['miq_request']
$evm.root['quota_source_type'] = $evm.parent['quota_source_type'] || $evm.object['quota_source_type']

if $evm.root['quota_source_type'].casecmp('group').zero?
  $evm.root['quota_source'] = @miq_request.requester.current_group
else
  $evm.root['quota_source'] = @miq_request.tenant
  $evm.root['quota_source_type'] = 'tenant'
end
