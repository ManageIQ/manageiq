#
# Description: This method validates the group or owner quotas using the values
# [max_group_cpu, max_group_memory, max_group_storage, max_owner_cpu, max_owner_memory, max_owner_storage]
# from values in the following order:
# 1. In the model
# 2. Group tags - This looks at the Group for the following
# tag values: [quota_max_cpu, quota_max_memory, quota_max_storage]
# 2a. Owner tags - This looks at the User for the following
# tag values: [quota_max_cpu, quota_max_memory, quota_max_storage]
#

# Initialize Variables
quota_exceeded = false
miq_request = $evm.root['miq_request']
miq_provision_request = miq_request.resource
user = miq_request.requester
group = user.current_group

# Specify whether quotas should be managed by group or user
manage_quotas_by_group = true

# Extract Request Information
vms_in_request = miq_provision_request.get_option(:number_of_vms).to_i
cpu_in_request = miq_provision_request.get_option(:number_of_cpus).to_i
if cpu_in_request.zero?
  cpu_in_request = miq_provision_request.get_option(:number_of_sockets).to_i * miq_provision_request.get_option(:cores_per_socket).to_i
end
memory_in_request = miq_provision_request.get_option(:vm_memory).to_i

# Calculate total CPU based on number of VMs in request
total_cpu_in_request = vms_in_request * cpu_in_request
$evm.log("info", "Total Requested Provisioning vCPUs: #{total_cpu_in_request}")

# Calculate total Memory based on number of VMs in request
total_memory_in_request = vms_in_request * memory_in_request
total_memory_nice = "%.2fGB" % (total_memory_in_request / 1024)
$evm.log("info", "Total Requested Provisioning Memory: #{total_memory_nice}")

# Calculate total Storage based on number of VMs in request
vm_size = miq_provision_request.vm_template.provisioned_storage
total_storage_nice = "%.2fGB" % (vm_size * vms_in_request / 1024**3)
$evm.log("info", "Total Requested Provisioning Storage: #{total_storage_nice}")

if manage_quotas_by_group
  # Available check_quota methods [:vms_by_group, :vms_by_owner_and_group]
  quota_group = miq_provision_request.check_quota(:vms_by_group, :include_retired_vms => false)
  $evm.log("info", "Inspecting quota_group:<#{quota_group.inspect}>")

  ##########################
  #
  # Group CPU Quota Check
  #
  ##########################
  $evm.log("info", "Beginning Group CPU Quota Check")
  $evm.log("info", "Group: <#{group.description}> current CPU usage: <#{quota_group[:cpu]}>")

  max_group_cpu   = nil
  g_quota_exceeded_reason1 = nil

  # Use value from model unless specified above
  max_group_cpu ||= $evm.object['max_group_cpu']
  unless max_group_cpu.nil?
    $evm.log("info", "Found quota from model <quota_max_cpu> with value <#{max_group_cpu}>")
  end

  # Get tag from Group
  tag_max_group_cpu = group.tags(:quota_max_cpu).first
  unless tag_max_group_cpu.nil?
    $evm.log("info", "Found quota from Group <#{group.description}> tag <:quota_max_cpu> with value <#{tag_max_group_cpu}>")
  end

  # If group is tagged then override
  unless tag_max_group_cpu.nil?
    max_group_cpu = tag_max_group_cpu.to_i
    $evm.log("info", "Overriding quota from Group <#{group.description}> tag <:quota_max_cpu> with value <#{tag_max_group_cpu}>")
  end

  # Validate Group CPU Quota
  unless max_group_cpu.blank?
    if quota_group && (quota_group[:cpu] + total_cpu_in_request > max_group_cpu.to_i)
      $evm.log("info", "CPUs allocated for Group <#{quota_group[:cpu]}> +  Requested CPUs <#{total_cpu_in_request}> exceeds Quota Max CPUs <#{max_group_cpu}>")
      quota_exceeded = true
      g_total_vcpus = quota_group[:cpu]
      g_quota_exceeded_reason1 = "Group Allocated vCPUs #{g_total_vcpus} + Requested #{total_cpu_in_request} > Quota #{max_group_cpu}"
    end
  end

  ##########################
  #
  # Group Memory Quota Check
  #
  ##########################
  $evm.log("info", "Beginning Group Memory Quota Check")
  $evm.log("info", "Group: <#{group.description}> current Memory usage: <#{quota_group[:memory]}>")

  max_group_memory   = nil
  g_quota_exceeded_reason2 = nil

  # Use value from model unless specified above
  max_group_memory ||= $evm.object['max_group_memory']
  unless max_group_memory.nil?
    $evm.log("info", "Found quota from model <max_group_memory> with value:<#{max_group_memory}>")
  end

  # Get tag from Group
  tag_max_group_memory = group.tags(:quota_max_memory).first
  unless tag_max_group_memory.nil?
    $evm.log("info", "Found quota from group <#{group.description}> tag <quota_max_memory> with value <#{tag_max_group_memory}>")
  end

  # If group is tagged then override
  unless tag_max_group_memory.nil?
    max_group_memory = tag_max_group_memory.to_i
    $evm.log("info", "Overriding quota from group <#{group.description}> tag <quota_max_memory> with value <#{tag_max_group_memory}>")
  end

  # Validate Group Memory Quota
  unless max_group_memory.blank?
    if quota_group && (quota_group[:memory] + total_memory_in_request > max_group_memory.to_i)
      $evm.log("info", "Memory allocated for Group <#{quota_group[:memory]}> +  Requested Memory <#{total_memory_in_request}> exceeds Quota Max <#{max_group_memory}>")
      quota_exceeded = true
      g_mem_total_nice = "%.2fGB" % (quota_group[:memory] / 1024)
      g_mem_quota_nice = "%.2fGB" % (max_group_memory.to_i / 1024)
      g_quota_exceeded_reason2 = "Group Allocated Memory #{g_mem_total_nice} + Requested #{total_memory_nice} > Quota #{g_mem_quota_nice}"
    end
  end

  ##########################
  #
  # Group Storage Quota Check
  #
  ##########################
  $evm.log("info", "Beginning Group Storage Quota Check")
  $evm.log("info", "Group: <#{group.description}> current Storage usage: <#{quota_group[:allocated_storage]}>")

  max_group_storage   = nil
  g_quota_exceeded_reason3 = nil

  # Use value from model unless specified above
  max_group_storage ||= $evm.object['max_group_storage']
  unless max_group_storage.nil?
    $evm.log("info", "Found quota from model <max_group_storage> with value:<#{max_group_storage}GB>")
  end

  # Get tag from Group
  tag_max_group_storage = group.tags(:quota_max_storage).first
  unless tag_max_group_storage.nil?
    $evm.log("info", "Found quota from group <#{group.description}> tag <quota_max_storage> with value <#{tag_max_group_storage}>")
  end

  # If group is tagged then override
  unless tag_max_group_storage.nil?
    max_group_storage = tag_max_group_storage.to_i
    $evm.log("info", "Overriding quota from Group <#{group.description}> tag <quota_max_storage> with value <#{tag_max_group_storage}GB> or <#{tag_max_group_storage.to_i * (1024**3)} bytes>")
  end

  # Validate Group Storage Quota
  unless max_group_storage.blank?
    max_group_storage = max_group_storage.to_i
    if quota_group && (quota_group[:allocated_storage] + vm_size > max_group_storage.to_i * (1024**3))
      $evm.log("info", "Storage allocated for Group <#{quota_group[:allocated_storage]}> +  Requested Storage <#{vm_size}> exceeds Quota Max <#{max_group_storage}>")
      quota_exceeded = true
      g_stor_total_nice = "%.2fGB" % (quota_group[:allocated_storage] / 1024**3)
      g_stor_quota_nice = "%.2fGB" % (max_group_storage)
      g_quota_exceeded_reason3 = "Group Allocated Storage #{g_stor_total_nice} + Requested #{total_storage_nice} > Quota #{g_stor_quota_nice}"
    end
  end

else
  # Available check_quota methods [:vms_by_owner, :vms_by_owner_and_group]
  quota_owner = miq_provision_request.check_quota(:vms_by_owner, :include_retired_vms => false)
  $evm.log("info", "Inspecting quota_owner:<#{quota_owner.inspect}>")

  ##########################
  #
  # Owner CPU Quota Check
  #
  ##########################
  $evm.log("info", "Beginning Owner CPU Quota Check")
  $evm.log("info", "Owner: <#{user.name}> current CPU usage: <#{quota_owner[:cpu]}>")

  max_owner_cpu   = nil
  o_quota_exceeded_reason1 = nil

  # Use value from model unless specified above
  max_owner_cpu ||= $evm.object['max_owner_cpu']
  unless max_owner_cpu.nil?
    $evm.log("info", "Found quota from model <max_owner_cpu> with value:<#{max_owner_cpu}>")
  end

  # Get tag from Owner
  tag_max_owner_cpu = user.tags(:quota_max_cpu).first
  unless tag_max_owner_cpu.nil?
    $evm.log("info", "Found quota from user <#{user.name}> tag <quota_max_cpu> with value <#{tag_max_owner_cpu}>>")
  end

  # If owner is tagged then override
  unless tag_max_owner_cpu.nil?
    max_owner_cpu = tag_max_owner_cpu.to_i
    $evm.log("info", "Overriding quota from User <#{user.name}> tag <quota_max_cpu> with value <#{tag_max_owner_cpu}>")
  end

  # Validate Owner CPU Quota
  unless max_owner_cpu.blank?
    if quota_owner && (quota_owner[:cpu] + total_cpu_in_request > max_owner_cpu.to_i)
      $evm.log("info", "CPUs allocated for Owner <#{quota_owner[:cpu]}> +  Requested CPUs <#{total_cpu_in_request}> exceeds Quota Max <#{max_owner_cpu}>")
      quota_exceeded = true
      o_total_vcpus = quota_owner[:cpu]
      o_quota_exceeded_reason1 = "Owner Allocated vCPUs #{o_total_vcpus} + Requested #{total_cpu_in_request} > Quota #{max_owner_cpu}"
    end
  end

  ##########################
  #
  # Owner Memory Quota Check
  #
  ##########################
  $evm.log("info", "Beginning Owner Memory Quota Check")
  $evm.log("info", "Owner: <#{user.name}> current Memory usage: <#{quota_owner[:memory]}>")

  max_owner_memory   = nil
  o_quota_exceeded_reason2 = nil

  # Use value from model unless specified above
  max_owner_memory ||= $evm.object['max_owner_memory']
  unless max_owner_memory.nil?
    $evm.log("info", "Found quota from model <max_owner_memory> with value:<#{max_owner_memory}>")
  end

  # Get tag from Owner
  tag_max_owner_memory = user.tags(:quota_max_memory).first
  unless tag_max_owner_memory.nil?
    $evm.log("info", "Found quota from user <#{user.name}> tag <quota_max_memory> with value <#{tag_max_owner_memory}>")
  end

  # If owner is tagged then override
  unless tag_max_owner_memory.nil?
    max_owner_memory = tag_max_owner_memory.to_i
    $evm.log("info", "Overriding quota from User <#{user.name}> tag <quota_max_memory> with value <#{tag_max_owner_memory}>")
  end

  # Validate Owner Memory Quota
  unless max_owner_memory.blank?
    if quota_owner && (quota_owner[:memory] + total_memory_in_request > max_owner_memory.to_i)
      $evm.log("info", "Memory allocated for Owner <#{quota_owner[:memory]}> +  Requested Memory <#{total_memory_in_request}> exceeds Quota Max <#{max_owner_memory}>")
      quota_exceeded = true
      o_mem_total_nice = "%.2fGB" % (quota_owner[:memory] / 1024)
      o_mem_quota_nice = "%.2fGB" % (max_owner_memory.to_i / 1024)
      o_quota_exceeded_reason2 = "Owner Allocated Memory #{o_mem_total_nice} + Requested #{total_memory_nice} > Quota #{o_mem_quota_nice}"
    end
  end

  ##########################
  #
  # Owner Storage Quota Check
  #
  ##########################
  $evm.log("info", "Beginning Owner Storage Quota Check")
  $evm.log("info", "Owner: <#{user.name}> current Storage usage: <#{quota_owner[:allocated_storage]}>")

  max_owner_storage   = nil
  o_quota_exceeded_reason3 = nil

  # Use value from model unless specified above
  max_owner_storage ||= $evm.object['max_owner_storage']
  unless max_owner_storage.nil?
    $evm.log("info", "Found quota from model <max_owner_storage> with value:<#{max_owner_storage}GB>")
  end

  # Get tag from Owner
  tag_max_owner_storage = user.tags(:quota_max_storage).first
  unless tag_max_owner_storage.nil?
    $evm.log("info", "Found quota from user <#{user.name}> tag <quota_max_storage> with value <#{tag_max_owner_storage}GB> or <#{tag_max_group_storage * (1024**3)} bytes>")
  end

  # If owner is tagged then override
  unless tag_max_owner_storage.nil?
    max_owner_storage = tag_max_owner_storage.to_i
    $evm.log("info", "Overriding quota from User <#{user.name}> tag <quota_max_storage> with value <#{tag_max_owner_storage}GB>")
  end

  # Validate Owner Storage Quota
  unless max_owner_storage.blank?
    max_owner_storage = max_owner_storage.to_i
    if quota_owner && (quota_owner[:allocated_storage] + vm_size > max_owner_storage.to_i * (1024**3))
      $evm.log("info", "Storage allocated for Owner <#{quota_owner[:allocated_storage]}> +  Requested Storage <#{vm_size}> exceeds Quota Max <#{max_owner_storage}>")
      quota_exceeded = true
      o_stor_total_nice = "%.2fGB" % (quota_owner[:allocated_storage] / 1024**3)
      o_stor_quota_nice = "%.2fGB" % (max_owner_storage)
      o_quota_exceeded_reason3 = "Owner Allocated Storage #{o_stor_total_nice} + Requested #{total_storage_nice} > Quota #{o_stor_quota_nice}"
    end
  end
end

##########################
#
# Quota Exceeded Check
#
##########################
if quota_exceeded == true
  msg = ""
  # msg +=  "VMs cannot be provisioned at this time due to the following quota limits: "
  msg +=  "Request denied due to the following quota limits:"
  msg += "(#{g_quota_exceeded_reason1}) " unless g_quota_exceeded_reason1.nil?
  msg += "(#{g_quota_exceeded_reason2}) " unless g_quota_exceeded_reason2.nil?
  msg += "(#{g_quota_exceeded_reason3})" unless g_quota_exceeded_reason3.nil?
  msg += "(#{o_quota_exceeded_reason1}) " unless o_quota_exceeded_reason1.nil?
  msg += "(#{o_quota_exceeded_reason2}) " unless o_quota_exceeded_reason2.nil?
  msg += "(#{o_quota_exceeded_reason3})" unless o_quota_exceeded_reason3.nil?
  $evm.log("info", "Inspecting Messge:<#{msg}>")

  miq_provision_request.set_message(msg)

  $evm.root['ae_result'] = 'error'
  $evm.object['reason']  = msg
end
