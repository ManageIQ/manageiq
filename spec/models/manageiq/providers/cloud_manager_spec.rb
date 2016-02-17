describe EmsCloud do
  it ".types" do
    expected_types = [ManageIQ::Providers::Amazon::CloudManager,
                      ManageIQ::Providers::Azure::CloudManager,
                      ManageIQ::Providers::Openstack::CloudManager,
                      ManageIQ::Providers::Google::CloudManager].collect(&:ems_type)
    expect(described_class.types).to match_array(expected_types)
  end

  it ".supported_subclasses" do
    expected_subclasses = [ManageIQ::Providers::Amazon::CloudManager,
                           ManageIQ::Providers::Azure::CloudManager,
                           ManageIQ::Providers::Openstack::CloudManager,
                           ManageIQ::Providers::Google::CloudManager]
    expect(described_class.supported_subclasses).to match_array(expected_subclasses)
  end

  it ".supported_types" do
    expected_types = [ManageIQ::Providers::Amazon::CloudManager,
                      ManageIQ::Providers::Azure::CloudManager,
                      ManageIQ::Providers::Openstack::CloudManager,
                      ManageIQ::Providers::Google::CloudManager].collect(&:ems_type)
    expect(described_class.supported_types).to match_array(expected_types)
  end

  context "#flavors" do
    before do
      @ems = FactoryGirl.create(:ems_cloud)
      MyInstanceFlavor = Class.new(Flavor)
      MyDatabaseFlavor = Class.new(DatabaseFlavor)
      MyInstanceFlavor.create(:name => 'vm', :ext_management_system => @ems)
      MyDatabaseFlavor.create(:name => 'db', :ext_management_system => @ems)
    end

    it { expect(@ems.flavors.first).not_to be_a DatabaseFlavor }
    it { expect(@ems.database_flavors.first).to be_a DatabaseFlavor}
  end
end
