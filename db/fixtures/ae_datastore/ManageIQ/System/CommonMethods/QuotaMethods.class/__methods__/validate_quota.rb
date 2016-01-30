GIGA_SIZE = 1_073_741_824.0
MEGA_SIZE = 1_048_576.0
KILO_SIZE = 1024.0

def request_info
  @service = ($evm.root['vmdb_object_type'] == 'service_template_provision_task') ? true : false
  @miq_request = $evm.root['miq_request']
  $evm.log(:info, "Request: #{@miq_request.description} id: #{@miq_request.id} ")
end

def source_info
  @source = $evm.root['quota_source']
end

def quota_check(item, used, requested, quota_max, quota_warn)
  $evm.log(:info, "Item: #{item} Used: (#{used}) Requested: (#{requested}) Max: (#{quota_max}) Warn: (#{quota_warn})")
  return unless quota_max + quota_warn > 0
  if quota_exceeded?(item, used, requested, quota_max)
    quota_exceeded(item, reason(item, used, requested, quota_max), false)
  elsif quota_exceeded?(item, used, requested, quota_warn)
    quota_exceeded(item, reason(item, used, requested, quota_warn), true)
  end
end

def quota_exceeded?(item, used, requested, quota)
  return false if quota.zero?
  if used + requested > quota
    $evm.log(:info, "#{item} Quota exceeded: Used(#{display_value(item, used, 2)})" \
      " + Requested(#{display_value(item, requested, 2)}) > Quota(#{display_value(item, quota, 2)})")
    return true
  end
  false
end

def quota_exceeded(item, reason, warn)
  warn ? quota_warn_exceeded(item, reason) : quota_limit_exceeded(item, reason)
  true
end

def reason_key(item, warn)
  "#{item}_quota_#{warn}exceeded".to_sym
end

def quota_limit_exceeded(item, reason)
  key = reason_key(item, nil)
  $evm.log(:info, "Quota maximum allowed exceeded for key: #{key} reason: #{reason}")
  @max_exceeded[key] = reason
end

def quota_warn_exceeded(item, reason)
  key = reason_key(item, "warn_")
  $evm.log(:info, "Quota Warning limit exceeded for key: #{key} reason: #{reason}")
  @warn_exceeded[key] = reason
end

def display_value(item, value, _precision)
  return value unless %w(memory storage).include?(item)
  case
  when value == 1
    "1 Byte"
  when value < KILO_SIZE
    "%d Bytes" % (value)
  when value < MEGA_SIZE
    "%.2f KB" % (value / KILO_SIZE)
  when value < GIGA_SIZE
    "%.2f MB" % (value / MEGA_SIZE)
  else
    "%.2f GB" % (value / GIGA_SIZE)
  end
end

def reason(item, used, requested, limits)
  "#{item} - Used: #{display_value(item, used, 2)} plus requested: #{display_value(item, requested, 2)}" \
  " exceeds quota: #{display_value(item, limits, 2)}"
end

def check_quotas
  %w(storage vms cpu memory).each do |i|
    key = i.to_sym
    quota_check(i, @used[key].to_i, @requested[key].to_i, @max_limit[key].to_i, @warn_limit[key].to_i)
  end
end

def check_quota_results
  message = ""
  unless @max_exceeded.empty?
    max_message = message_text(nil, "Request exceeds maximum allowed for the following: ", @max_exceeded)
    message = set_exceeded_results(message, max_message, :quota_max_exceeded, "error")
  end
  unless @warn_exceeded.empty?
    warn_message = message_text('warn_', "Request exceeds warning limits for the following: ", @warn_exceeded)
    message = set_exceeded_results(message, warn_message, :quota_warn_exceeded, "ok")
  end
  @miq_request.set_message(message[0..250])
end

def set_exceeded_results(request_message, new_message, request_option, ae_result_text)
  request_message += new_message
  @miq_request.set_option(request_option, request_message)
  $evm.root['ae_result'] = ae_result_text
  request_message
end

def message_text(type, msg, exceeded_hash)
  message = msg
  ["cpu_quota_#{type}exceeded".to_sym,
   "memory_quota_#{type}exceeded".to_sym,
   "storage_quota_#{type}exceeded".to_sym,
   "vms_quota_#{type}exceeded".to_sym].each do |q|
    message += "(#{exceeded_hash[q]}) " if exceeded_hash[q]
  end
  message
end

def get_hash(root_obj_value, yaml_load_name)
  return nil if root_obj_value.nil? && $evm.root[yaml_load_name].nil?
  root_obj_value.nil? ? YAML.load($evm.root[yaml_load_name]) : root_obj_value
end

def setup
  @requested = get_hash($evm.root['quota_requested'], 'quota_requested_yaml')
  @used = get_hash($evm.root['quota_used'], 'quota_used_yaml')
  @max_limit = get_hash($evm.root['quota_limit_max'], 'quota_limit_max_yaml')
  @warn_limit = get_hash($evm.root['quota_limit_warn'], 'quota_limit_warn_yaml')
  @max_exceeded = {}
  @warn_exceeded = {}
end

def quotas_configured?
  @max_limit.values.sum + @warn_limit.values.sum
end

def limits_set(limit_hash)
  return false if limit_hash.blank?
  limit_hash.values.sum.zero? ? false : true
end

def error(type)
  msg = "Unable to calculate requested #{type}, due to an error getting the #{type}"
  $evm.log(:error, " #{msg}")
  $evm.root['ae_result'] = 'error'
  raise msg
end

setup

request_info
error("request") if @miq_request.nil?

source_info
error("source") if @source.nil?

error("used") if @used.nil?

error("requested") if @requested.nil?

$evm.log(:info, "quota_warning: #{@warn_limit.inspect}")
$evm.log(:info, "quota_limits: #{@max_limit.inspect}")

if !limits_set(@max_limit) && !limits_set(@warn_limit)
  $evm.log(:info, "No Quota limits set. No quota check being done.")
  $evm.root['ae_result'] = 'ok'
  exit MIQ_OK
end

check_quotas

check_quota_results
