RSpec.describe ContainerQuotaItem do
  it "converts float to string" do
    quota_item = ContainerQuotaItem.new(:resource       => 'cpu',
                                        :quota_desired  => 4.2,
                                        :quota_enforced => 1.99,
                                        :quota_observed => 0.01)

    expect(quota_item).to have_attributes(:quota_desired_display  => '4.2',
                                          :quota_enforced_display => '1.99',
                                          :quota_observed_display => '0.01')
  end

  it "rounds float to int" do
    quota_item = ContainerQuotaItem.new(:resource       => 'pods',
                                        :quota_desired  => 42.0,
                                        :quota_enforced => 1.0,
                                        :quota_observed => 0.0)

    expect(quota_item).to have_attributes(:quota_desired_display  => '42',
                                          :quota_enforced_display => '1',
                                          :quota_observed_display => '0')
  end
end
