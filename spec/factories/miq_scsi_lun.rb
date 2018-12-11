FactoryBot.define do
  factory :miq_scsi_lun do
    sequence(:device_name) { |n| "miq_scsi_lun_#{n}" }
    sequence(:lun)         { 0 }
    sequence(:device_type) { 'cdrom' }
  end
end
