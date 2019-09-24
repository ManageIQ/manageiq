FactoryBot.define do
  factory :chargeable_field do
    metric { 'unknown' }
    group  { 'unknown' }
    source { 'unknown' }
    initialize_with { ChargeableField.find_or_create_by!(:metric => metric, :group => group, :source => source) }
  end

  factory :chargeable_field_fixed_compute_1, :parent => :chargeable_field do
    description { 'Fixed Compute Cost 1' }
    source      { 'compute_1' }
    group       { 'fixed' }
    metric      { 'fixed_compute_1' }
  end

  factory :chargeable_field_cpu_used, :parent => :chargeable_field do
    description { 'Used CPU in MHz' }
    metric      { 'cpu_usagemhz_rate_average' }
    group       { 'cpu' }
    source      { 'used' }
    detail_measure { FactoryBot.build(:chargeback_measure_hz) }
  end

  factory :chargeable_field_cpu_allocated, :parent => :chargeable_field do
    description { 'Allocated CPU Count' }
    metric      { 'derived_vm_numvcpus' }
    group       { 'cpu' }
    source      { 'allocated' }
  end

  factory :chargeable_field_memory_allocated, :parent => :chargeable_field do
    description { 'Allocated Memory in MB' }
    metric      { 'derived_memory_available' }
    group       { 'memory' }
    source      { 'allocated' }
    detail_measure { FactoryBot.build(:chargeback_measure_bytes) }
  end

  factory :chargeable_field_storage_allocated, :parent => :chargeable_field do
    description { 'Allocated Disk Storage in Bytes' }
    metric      { 'derived_vm_allocated_disk_storage' }
    group       { 'storage' }
    source      { 'allocated' }
    detail_measure { FactoryBot.build(:chargeback_measure_bytes) }
  end

  factory :chargeable_field_cpu_cores_used, :parent => :chargeable_field do
    description { 'Used CPU in Cores' }
    metric      { 'v_derived_cpu_total_cores_used' }
    group       { 'cpu_cores' }
    source      { 'used' }
  end

  factory :chargeable_field_cpu_cores_allocated, :parent => :chargeable_field do
    description { 'Allocated CPU in Cores' }
    metric      { 'derived_vm_numvcpu_cores' }
    group       { 'cpu_cores' }
    source      { 'allocated' }
  end

  factory :chargeable_field_memory_used, :parent => :chargeable_field do
    description { 'Used Memory in MB' }
    metric      { 'derived_memory_used' }
    group       { 'memory' }
    source      { 'used' }
    detail_measure { FactoryBot.build(:chargeback_measure_bytes) }
  end

  factory :chargeable_field_net_io_used, :parent => :chargeable_field do
    description { 'Used Network I/O in KBps' }
    metric      { 'net_usage_rate_average' }
    group       { 'net_io' }
    source      { 'used' }
    detail_measure { FactoryBot.build(:chargeback_measure_bps) }
  end

  factory :chargeable_field_disk_io_used, :parent => :chargeable_field do
    description { 'Used disk I/O in KBps' }
    metric      { 'disk_usage_rate_average' }
    group       { 'disk_io' }
    source      { 'used' }
    detail_measure { FactoryBot.build(:chargeback_measure_bps) }
  end

  factory :chargeable_field_storage_used, :parent => :chargeable_field do
    description { 'Used Disk Storage in Bytes' }
    metric      { 'derived_vm_used_disk_storage' }
    group       { 'storage' }
    source      { 'used' }
    detail_measure { FactoryBot.build(:chargeback_measure_bytes) }
  end

  factory :chargeable_field_metering_used, :parent => :chargeable_field do
    description { 'Metering Used Hours' }
    metric      { 'metering_used_hours' }
    group       { 'metering' }
    source      { 'used' }
  end
end
