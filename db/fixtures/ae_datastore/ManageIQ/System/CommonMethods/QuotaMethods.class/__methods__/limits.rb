#
# Description: Get quota values.
#
QUOTA_ATTRIBUTES = %w(storage vms cpu memory)

def quota_values(model_attribute, tag_name)
  $evm.log(:info, "Getting Quota Values for Model: #{model_attribute} Tag Name: #{tag_name}")
  object_value = quota_model_value(model_attribute) unless $evm.parent.nil?
  tag = @source.tags(tag_name).first
  tag_value = tag_value(tag_name, tag) || 0
  final_quota_value(tag_value, object_value)
end

def quota_model_value(model_attr)
  parent_model_value(model_attr)
end

def final_quota_value(tag_quota_value, object_quota_value = 0)
  val = tag_quota_value.zero? ? object_quota_value : tag_quota_value
  $evm.log(:info, "Final Quota Value: #{val}")
  val
end

def vmdb_object(object, id)
  $evm.vmdb(object).find_by_id(id)
end

def parent_model_value(attr)
  value = $evm.parent[attr].to_i
  $evm.log(:info, "Quota Model #{attr}: #{value}") unless value.zero?
  value
end

def tag_value(tag, tag_value)
  value = tag_value.to_i
  $evm.log(:info, "Quota Tag #{tag}: #{value}") unless value.zero?
  value
end

def get_option_value(request, option)
  request.get_option(option).to_i
end

def determine_quota_value(model_attribute, tag_name)
  $evm.log(:info, "Determine Quota Value: #{model_attribute} Tag name: #{tag_name}")
  quota_values(model_attribute, tag_name)
end

def error(type)
  msg = "Unable to calculate quota limits due to an error getting the Quota #{type}"
  $evm.log(:error, " #{msg}")
  $evm.root['ae_result'] = 'error'
  raise msg
end

@source = $evm.root['quota_source']
error("source") if @source.nil?

quota_max = {}
quota_warn = {}

QUOTA_ATTRIBUTES.each do |i|
  quota_max[i.to_sym] = quota_values("max_#{i}", "quota_max_#{i}".to_sym)
  quota_warn[i.to_sym] = quota_values("warn_#{i}", "quota_warn_#{i}".to_sym)
end

$evm.root['quota_limit_max'] = quota_max
$evm.root['quota_limit_warn'] = quota_warn
