FactoryBot.define do
  factory :dialog_group do
    sequence(:label) { |n| "Dialog Group #{n}" }

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

  factory :dialog_group_with_field, :parent => :dialog_group do
    after(:create) do |dialog_group|
      create(:dialog_field_text_box, :dialog_group => dialog_group)
    end
  end
end
