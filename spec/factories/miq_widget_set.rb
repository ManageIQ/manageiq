FactoryBot.define do
  factory :miq_widget_set do
    sequence(:name)         { |n| "widget_set_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "widget_set_#{seq_padded_for_sorting(n)}" }

    transient do
      widget_id             { nil }
      last_group_db_updated { nil }
    end

    after(:build) do |widget_set, env|
      unless widget_set.set_data
        widget_set.valid?
        widget_set.set_data[:col1] << (env.widget_id || FactoryBot.create(:miq_widget).id)
      end

      unless widget_set.owner_id
        widget_set.owner = User.current_user || FactoryBot.create(:miq_group)
      end
    end
  end
end
