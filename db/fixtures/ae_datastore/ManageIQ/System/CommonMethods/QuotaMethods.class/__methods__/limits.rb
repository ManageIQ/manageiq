#
# Description: Get quota values.
#

QUOTA_ATTRIBUTES = %w(storage vms cpu memory).freeze

def quota_values(model_attribute, tag_name)
  $evm.log(:info, "Getting Quota Values for Model: #{model_attribute} Tag Name: #{tag_name}")
  object_value = quota_model_value(model_attribute) unless $evm.parent.nil?
  tag = @source.tags(tag_name).first
  tag_value = tag_value(tag_name, tag) || 0
  final_quota_value(tag_value, object_value)
end

def tenant_quota_values
  tenant_values = {}
  @source.tenant_quotas.each do |q|
    value = q.value.to_i
    name = q.name.chomp('_allocated')
    name = 'memory' if name == 'mem'
    tenant_values[name.to_sym] = value
  end
  $evm.log(:info, "Getting Tenant Quota Values for: #{tenant_values}")
  $evm.root['quota_limit_max'] = tenant_values
  $evm.root['quota_limit_warn'] = {:cpu => 0, :memory => 0, :storage => 0, :vms => 0}
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
  if attr.ends_with?("storage") || attr.ends_with?("memory")
    value = value.megabytes
  end
  value
end

def tag_value(tag, tag_value)
  value = tag_value.to_i
  $evm.log(:info, "Quota Tag #{tag}: #{value}") unless value.zero?
  if tag == :quota_max_storage
    value = value.gigabytes
  elsif tag == :quota_max_memory
    value = value.megabytes
  end
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
  msg = "Unable to calculate requested #{type}, due to an error getting the #{type}"
  $evm.log(:error, " #{msg}")
  $evm.root['ae_result'] = 'error'
  raise msg
end

def quota_by_tenant?
  $evm.root['quota_source_type'] == 'tenant'
end

def set_root_limit_values(quota_max, quota_warn)
  $evm.root['quota_limit_max'] = quota_max
  $evm.root['quota_limit_warn'] = quota_warn
end

def model_and_tag_quota_values
  $evm.log(:info, "Getting #{$evm.root['quota_source_type']} and Tag Quota source Values.")
  quota_max = {}
  quota_warn = {}
  QUOTA_ATTRIBUTES.each do |name|
    quota_max[name.to_sym] = quota_values("max_#{name}", "quota_max_#{name}".to_sym)
    quota_warn[name.to_sym] = quota_values("warn_#{name}", "quota_warn_#{name}".to_sym)
  end
  set_root_limit_values(quota_max, quota_warn)
end

def limits_set(limit_hash)
  return false if limit_hash.blank?
  limit_hash.values.sum.zero? ? false : true
end

@source = $evm.root['quota_source']
error("source") if @source.nil?

quota_by_tenant? ? tenant_quota_values : model_and_tag_quota_values

if !limits_set($evm.root['quota_limit_max']) && !limits_set($evm.root['quota_limit_warn'])
  $evm.log(:info, "No Quota limits set. No quota check being done.")
  $evm.root['ae_result'] = 'ok'
  $evm.root['ae_next_state'] = 'finished'
  exit MIQ_OK
end
