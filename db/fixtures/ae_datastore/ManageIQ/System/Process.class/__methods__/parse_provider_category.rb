#
# Description: Sets root object ae_provider_category to cloud/infra
#

INFRASTRUCTURE = 'infrastructure'
CLOUD          = 'cloud'
UNKNOWN        = 'unknown'

def vm_detect_category(vm)
  return nil unless vm.respond_to?(:cloud)
  vm.cloud ? CLOUD : INFRASTRUCTURE
end

def orchestration_stack_detect_category(_stack)
  CLOUD
end

def miq_request_detect_category(miq_request)
  vm_detect_category(miq_request.source)
end

def miq_provision_detect_category(miq_provision)
  vm_detect_category(miq_provision.source)
end

def vm_migrate_task_detect_category(miq_provision)
  vm_detect_category(miq_provision.source)
end

def miq_host_provision_detect_category(_)
  INFRASTRUCTURE
end

def platform_category_detect_category(platform_category)
  platform_category = INFRASTRUCTURE if platform_category == 'infra'
  platform_category
end

def category_for_key(key)
  send("#{key}_detect_category", $evm.root[key]) if $evm.root.attributes.key?(key)
end

provider_category = nil
keys = %w(vm orchestration_stack miq_request miq_provision miq_host_provision vm_migrate_task platform_category)
key_found = keys.detect { |key| provider_category = category_for_key(key) }

$evm.root['ae_provider_category'] = provider_category || UNKNOWN
$evm.log("info", "Parse Provider Category Key: #{key_found.inspect}  Value: #{$evm.root['ae_provider_category']}")
