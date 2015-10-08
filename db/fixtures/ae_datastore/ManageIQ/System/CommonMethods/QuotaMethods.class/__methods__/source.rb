#
# Description: get quota source.
#

@miq_request = $evm.root['miq_request']
$evm.log(:info, "Request: #{@miq_request.description} id: #{@miq_request.id} ")

user = @miq_request.requester
$evm.root['quota_source'] = user.current_group
$evm.log(:info, "Setting Quota Source #{$evm.root['quota_source'].inspect}")
