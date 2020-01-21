FactoryBot.define do
  factory :miq_scsi_target do
    sequence(:iscsi_name)    { |n| "miq_scsi_target_#{n}" }
    sequence(:target)        { 5 }
    sequence(:miq_scsi_luns) { [] }
  end
end
