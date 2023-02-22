RSpec.describe ManageIQ::Providers::Regions do
  describe ".regions" do
    ExtManagementSystem.supported_types_for_create.select(&:supports_regions?).each do |klass|
      context klass.description do
        it "returns regions" do
          expect(klass.module_parent::Regions.regions.count).not_to be_zero
        end
      end
    end
  end

  describe ".all" do
    ExtManagementSystem.supported_types_for_create.select(&:supports_regions?).each do |klass|
      context klass.description do
        it "returns regions" do
          expect(klass.module_parent::Regions.all.count).not_to be_zero
        end
      end
    end
  end

  describe ".names" do
    ExtManagementSystem.supported_types_for_create.select(&:supports_regions?).each do |klass|
      context klass.description do
        it "returns regions" do
          expect(klass.module_parent::Regions.all.count).not_to be_zero
        end
      end
    end
  end
end
