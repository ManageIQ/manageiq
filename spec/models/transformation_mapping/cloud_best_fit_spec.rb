describe TransformationMapping::CloudBestFit do
  let(:ems)         { FactoryGirl.create(:ems_openstack) }
  let(:vm)          { FactoryGirl.create(:vm_vmware, :hardware => vm_hardware) }
  let(:vm_hardware) { FactoryGirl.create(:hardware, :cpu1x2, :ram1GB) }

  subject { described_class.new(vm, ems) }

  it "no flavors on the provider" do
    expect(subject.available_fit_flavors).to match_array([])
    expect(subject.best_fit_flavor).to be_nil
  end

  it "no flavors match" do
    ems.flavors.create!(:cpus => 1, :memory => 512.megabytes)

    expect(subject.available_fit_flavors).to match_array([])
    expect(subject.best_fit_flavor).to be_nil
  end

  it "one flavor matches" do
    ems.flavors.create!(:cpus => 2, :memory => 512.megabytes)
    flavor = ems.flavors.create!(:cpus => 2, :memory => 1.gigabyte)

    expect(subject.available_fit_flavors).to match_array([flavor])
    expect(subject.best_fit_flavor).to eq(flavor)
  end

  it "multiple flavors match" do
    ems.flavors.create!(:cpus => 2, :memory => 512.megabytes)
    flavor1 = ems.flavors.create!(:cpus => 2, :memory => 1.gigabyte)
    flavor2 = ems.flavors.create!(:cpus => 2, :memory => 2.gigabytes)
    flavor3 = ems.flavors.create!(:cpus => 4, :memory => 1.gigabyte)

    expect(subject.available_fit_flavors).to match_array([flavor1, flavor2, flavor3])
    expect(subject.best_fit_flavor).to eq(flavor1)
  end
end
