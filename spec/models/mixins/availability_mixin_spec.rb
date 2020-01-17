RSpec.describe AvailabilityMixin do
  let(:test_class) do
    Class.new do
      include AvailabilityMixin

      def validate_bogus_feature_01
        {:available => true, :message => nil}
      end

      def validate_bogus_feature_02
        {:available => false, :message => "Bogus Feature 02 is not available"}
      end
    end
  end

  let(:test_inst) { test_class.new }

  context "available feature" do
    let(:feature) { :bogus_feature_01 }

    it "is_available? returns true" do
      expect(test_inst.is_available?(feature)).to be_truthy
    end

    it "is_available_now_error_message returns nil" do
      expect(test_inst.is_available_now_error_message(feature)).to be_nil
    end
  end

  context "unavailable feature" do
    let(:feature) { :bogus_feature_02 }

    it "is_available? returns false" do
      expect(test_inst.is_available?(feature)).to be_falsey
    end

    it "is_available_now_error_message returns error message" do
      expect(test_inst.is_available_now_error_message(feature)).not_to be_nil
    end
  end
end
