FactoryGirl.define do
  factory :dialog_tab do
    # skip validate_children callback for general dialog testing
    before(:create) { |d| d.stub(:validate_children) }
  end
end
