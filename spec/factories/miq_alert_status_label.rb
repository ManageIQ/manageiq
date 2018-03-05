FactoryGirl.define do
  factory :miq_alert_status_label do
    name 'mylabelname'
    value 'mylabelvalue'

    # By default `FactoryGirl` calls the `save!` method when the instance is created, but we don't
    # want to do that for this class because it isn't persisted to any table, and it doesn't have
    # that `save!` method.
    skip_create
  end
end
