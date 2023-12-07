RSpec.describe ManageIQ::Providers::Regions, :providers_common => true do
  describe ".regions" do
    ExtManagementSystem.supported_types_for_create.select { |klass| klass.supports?(:regions) }.each do |klass|
      context klass.description do
        it "returns regions" do
          expect(klass.module_parent::Regions.regions.count).not_to be_zero
        end

        context "with additional_regions" do
          let(:ems_settings_name) { klass.module_parent::Regions.send(:ems_type) }
          before do
            stub_settings_merge(
              :ems => {ems_settings_name => {:additional_regions => {:foo => {:name => :my_special_region, :description => "My Special Region"}}}}
            )
          end

          it "includes the additional region" do
            expect(klass.module_parent::Regions.regions).to include("foo" => {:name => :my_special_region, :description => "My Special Region"})
          end
        end
      end
    end
  end

  describe ".all" do
    ExtManagementSystem.supported_types_for_create.select { |klass| klass.supports?(:regions) }.each do |klass|
      context klass.description do
        it "returns regions" do
          expect(klass.module_parent::Regions.all.count).not_to be_zero
        end

        context "with additional_regions" do
          let(:ems_settings_name) { klass.module_parent::Regions.send(:ems_type) }
          before do
            stub_settings_merge(
              :ems => {ems_settings_name => {:additional_regions => {:foo => {:name => :my_special_region, :description => "My Special Region"}}}}
            )
          end

          it "includes the additional region" do
            expect(klass.module_parent::Regions.all).to include({:name => :my_special_region, :description => "My Special Region"})
          end
        end
      end
    end
  end

  describe ".names" do
    ExtManagementSystem.supported_types_for_create.select { |klass| klass.supports?(:regions) }.each do |klass|
      context klass.description do
        it "returns regions" do
          expect(klass.module_parent::Regions.all.count).not_to be_zero
        end

        context "with additional_regions" do
          let(:ems_settings_name) { klass.module_parent::Regions.send(:ems_type) }
          before do
            stub_settings_merge(
              :ems => {ems_settings_name => {:additional_regions => {:foo => {:name => :my_special_region, :description => "My Special Region"}}}}
            )
          end

          it "includes the additional region" do
            expect(klass.module_parent::Regions.names).to include("foo")
          end
        end
      end
    end
  end
end
