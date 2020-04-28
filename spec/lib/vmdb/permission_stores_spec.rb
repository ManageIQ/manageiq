RSpec.describe Vmdb::PermissionStores do
  context "when no blacklist is present" do
    let(:instance) { described_class.new([]) }

    it "#can?" do
      expect(instance.can?('some_feature')).to be_truthy
    end

    it "#supported_ems_type?" do
      expect(instance.supported_ems_type?('some_ems_type')).to be_truthy
    end
  end

  context "when a blacklist is present" do
    let(:instance) { described_class.new(["blacklisted_feature", "ems-type:blacklisted_provider"]) }

    it "#can?" do
      expect(instance.can?('some_feature')).to        be_truthy
      expect(instance.can?('blacklisted_feature')).to be_falsey
    end

    it "#supported_ems_type?" do
      expect(instance.supported_ems_type?('some_ems_type')).to        be_truthy
      expect(instance.supported_ems_type?('blacklisted_provider')).to be_falsey
    end
  end
end
