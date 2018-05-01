describe CustomAttribute do
  let(:string_custom_attribute) { FactoryGirl.build(:custom_attribute, :name => "foo", :value => "string", :resource_type => 'ExtManagementSystem') }
  let(:time_custom_attribute) { FactoryGirl.build(:custom_attribute, :name => "bar", :value => DateTime.current, :resource_type => 'ExtManagementSystem') }
  let(:int_custom_attribute) { FactoryGirl.build(:custom_attribute, :name => "foobar", :value => 5, :resource_type => 'ExtManagementSystem') }

  it "returns the value type of String custom attributes" do
    expect(string_custom_attribute.value_type).to eq(:string)
  end

  it "returns the value type of DateTime custom attributes" do
    expect(time_custom_attribute.value_type).to eq(:datetime)
  end

  it "returns the value type of Integer custom attributes" do
    # TODO: Ruby 2.4 unifies fixnum and bignum into integer, we shouldn't be
    # returnings ruby types like this.
    expected = RUBY_VERSION >= "2.4.0" ? :integer : :fixnum
    expect(int_custom_attribute.value_type).to eq(expected)
  end

  context "must have a valid name" do
    let(:invalid_everywhere) { [":", " ", "-"] }
    let(:valid_everywhere)   { ["a", "_", "á"] }
    let(:valid_subsequent)   { ["1", "$"] }

    it "has a valid starting character" do
      valid_everywhere.each { |char| expect(CustomAttribute.new(:name => "#{char}zzzzz")).to be_valid }
      (invalid_everywhere + valid_subsequent).each { |char| expect(CustomAttribute.new(:name => "#{char}zzzzz")).not_to be_valid }
    end

    it "has a valid subsequent characters" do
      (valid_everywhere + valid_subsequent).each { |char| expect(CustomAttribute.new(:name => "a#{char}")).to be_valid }
      invalid_everywhere.each { |char| expect(CustomAttribute.new(:name => "a#{char}")).not_to be_valid }
    end
  end
end
