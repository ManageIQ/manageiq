FactoryBot.define do
  factory :dialog do
    sequence(:name) { |n| "Dialog #{n}" }

    # HACK: This is required because we were previously depending on rspec-mocks'
    # .stub monkeypatch here; the monkeypatch has since been removed and rspec-mocks
    # should NOT be used within factories anyway.
    # TODO: Rewrite dialog specs to properly mock this within the spec
    # skip validate_children callback for general dialog testing
    to_create do |instance|
      class << instance
        def validate_children; true; end
      end
      instance.save!
    end
  end

  factory :dialog_with_tab_and_group_and_field, :parent => :dialog do
    after(:create) do |dialog|
      create(:dialog_tab_with_group_and_field, :dialog => dialog)
    end
  end
end
