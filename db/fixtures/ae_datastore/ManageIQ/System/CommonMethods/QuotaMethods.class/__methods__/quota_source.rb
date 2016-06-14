#
# Description: Get quota source.
#

@miq_request = $evm.root['miq_request']
$evm.root['quota_source_type'] = $evm.parent['quota_source_type'] || $evm.object['quota_source_type']

case $evm.root['quota_source_type'].downcase
when 'group'
  $evm.root['quota_source'] = @miq_request.requester.current_group
when 'user'
  $evm.root['quota_source'] = @miq_request.requester
else
  $evm.root['quota_source'] = @miq_request.tenant
  $evm.root['quota_source_type'] = 'tenant'
end
