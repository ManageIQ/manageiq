#
# Description: Get quota values.
#

def quota_values(model_attribute, tag_name)
  $evm.log(:info, "Determine Quota Value: #{model_attribute} Tag name: #{tag_name}")
  object_value = quota_model_value(model_attribute)
  tag = @entity.tags(tag_name).first
  $evm.log(:info, "entity tags: #{@entity.tags} looking for Tag name: #{tag_name}")
  tag_value = tag_value(tag_name, tag) || 0
  final_quota_value(tag_value, object_value)
end

def quota_model_value(model_attr)
  model_value(model_attr)
end

def final_quota_value(tag_quota_value, object_quota_value)
  tag_quota_value.zero? ? object_quota_value : tag_quota_value
end

def vmdb_object(object, id)
  $evm.vmdb(object).find_by_id(id)
end

def model_value(attr)
  value = $evm.object[attr].to_i
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

$evm.log("info", "XXXXXXXXX Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")

@entity = $evm.root['quota_entity']
quota_max = {}
quota_warn = {}

%w(allocated_storage vms cpu memory).each do |i|
  quota_max[i.to_sym] = quota_values("max_#{i}", "quota_max_#{i}".to_sym)
  quota_warn[i.to_sym] = quota_values("warn_#{i}", "quota_warn_#{i}".to_sym)
end

$evm.root['quota_max'] = quota_max
$evm.root['quota_warn'] = quota_warn

$evm.log("info", "XXXXXXXXX Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")
