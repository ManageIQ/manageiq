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

  it "returns the value type of Fixnum custom attributes" do
    expect(int_custom_attribute.value_type).to eq(:fixnum)
  end
end
