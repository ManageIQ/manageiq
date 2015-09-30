#
# Description: get quota entity.
#

@miq_request = $evm.root['miq_request']
$evm.log(:info, "Request: #{@miq_request.description} id: #{@miq_request.id} ")

user = @miq_request.requester
$evm.root['quota_entity'] = user.current_group
$evm.log(:info, "Setting Quota Entity: #{$evm.root['quota_entity']}")
