FactoryGirl.define do
  factory :dialog_tab do
    sequence(:label) { |n| "Dialog Tab #{n}" }

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
end
