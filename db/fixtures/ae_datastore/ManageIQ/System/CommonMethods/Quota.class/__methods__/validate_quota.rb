
def request_info
  @service = ($evm.object['quota_type'] == 'service') ? true : false
  @miq_request = $evm.root['miq_request']
  $evm.log(:info, "Request: #{@miq_request.description} id: #{@miq_request.id} ")
end

def entity_info
  @entity = $evm.root['quota_entity']
end

def manage_quotas?
  manage_quotas = $evm.object['manage_quotas'] || true
  manage_quotas =~ (/(true|t|yes|y|1)$/i)
  true
end

def quota_check(item, used, requested, quota_max, quota_warn)
  $evm.log(:info, "Checking item: #{item} used (#{used}) Requested(#{requested}) Quota Max: (#{quota_max}) Quota Warn: (#{quota_warn})")
  if quota_exceeded?(item, used, requested, quota_max)
    quota_exceeded(item, reason(item, used, requested, quota_max), false)
  elsif quota_exceeded?(item, used, requested, quota_warn)
    quota_exceeded(item, reason(item, used, requested, quota_warn), true)
  end
end

def quota_exceeded?(item, used, requested, quota)
  if used + requested > quota
    $evm.log(:info, "Item: #{item} Quota exceeded: Used(#{used}) + Requested(#{requested}) > Quota(#{quota})")
    return true
  end
  false
end

def quota_exceeded(item, reason, warn)
  warn ? (@quota_results[:quota_warn_exceeded] = true) : (@quota_results[:quota_exceeded] = true)
  key = quota_reason_key(item)
  $evm.log(:info,  "Quota Limit exceeded for key: #{key} reason: #{reason}") if warn
  $evm.log(:info,  "Quota Warning exceeded for key: #{key} reason: #{reason}") unless warn
  @quota_results[key] = reason
  true
end

def quota_reason_key(item)
  "#{item}_quota_exceeded"
end

def reason(item, used, requested, limits)
  "#{item} - #{used} plus requested " \
  "#{requested} &gt; quota #{limits}"
end

def check_quotas
  log_quota

  %w(allocated_storage, vms, cpu, memory).each do |i|
    quota_check(i, @used_hash[i.to_sym], @requested_hash[i.to_sym],
                @quota_max_hash[i.to_sym], @quota_warn_hash[i.to_sym])
  end
end

def log_quota
  $evm.log(:info, "used: #{@used_hash.inspect}")
  $evm.log(:info, "requested: #{@requested_hash.inspect}")
  $evm.log(:info, "quota_warning: #{@quota_warn_hash.inspect}")
  $evm.log(:info, "quota_limits: #{@quota_max_hash.inspect}")
end

def check_quota_results
  if @quota_results[:quota_exceeded]
    quota_exceeded_message('limit')
    $evm.root['ae_result'] = 'error'
  elsif @quota_results[:quota_warn_exceeded]
    quota_exceeded_message('threshold')
    $evm.root['ae_result'] = 'ok'
    # send a warning message that quota threshold is close
    # $evm.instantiate('/Service/Provisioning/Email/ServiceTemplateProvisionRequest_Warning') if @service
  end
end

def quota_exceeded_message(type)
  err_message = nil
  case type
  when 'limit'
    err_message = message_text(nil, "Request denied due to the following quota limits: ")
  end
  warn_message = message_text('warn_', "Request warning due to the following quota thresholds: ")

  $evm.log(:info, "Quota Error Message: #{err_message}") if err_message
  $evm.log(:info, "Quota Warning Message: #{warn_message}") if warn_message
  message = err_message + warn_message
  @miq_request.set_message(message[0..250])
  @miq_request.set_option("quota_#{warn}exceeded".to_sym, message)
end

def message_text(type, msg)
  message = msg
  ["#{type}cpu_quota_exceeded".to_sym,
   "#{type}memory_quota_exceeded".to_sym,
   "#{type}storage_quota_exceeded".to_sym,
   "#{type}vms_quota_exceeded".to_sym].each do |q|
    message += "(#{@quota_results[q]}) " if @quota_results[q]
  end
  message
end

def setup
  @quota_results = {:quota_exceeded => false, :quota_warn_exceeded => false}
  @requested_hash = $evm.root['quota_requested']
  @used_hash = $evm.root['quota_used']
  @quota_max_hash = $evm.root['quota_max']
  @quota_warn_hash = $evm.root['quota_warn']
end

def error(type)
  msg = "Unable to calculate quota due to an error getting the #{type}"
  $evm.log(:warn, " #{msg}")
  $evm.root['ae_result'] = 'error'
  raise msg
end

unless manage_quotas?
  $evm.log(:warn, "Quota is turned off. ")
  return
end

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

setup

request_info
error("request") if @miq_request.nil?

entity_info
error("entity") if @entity.nil?

check_quotas

check_quota_results
