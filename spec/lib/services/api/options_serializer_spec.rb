RSpec.describe Api::OptionsSerializer do
  it "returns some default values when the class is nil" do
    actual = described_class.new(nil).serialize

    expected = {
      :attributes         => [],
      :virtual_attributes => [],
      :relationships      => [],
      :subcollections     => [],
      :data               => {}
    }

    expect(actual).to eq(expected)
  end
end
