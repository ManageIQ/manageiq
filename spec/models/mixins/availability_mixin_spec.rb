RSpec.describe AvailabilityMixin do
  let(:test_class) do
    Class.new do
      include AvailabilityMixin
      include SupportsFeatureMixin

      supports :feature3
      supports_not :feature4, :reason => "not available"

      def validate_feature1
        {:available => true, :message => nil}
      end

      def validate_feature2
        {:available => false, :message => "Bogus Feature 02 is not available"}
      end
    end
  end

  let(:test_inst) { test_class.new }

  describe '.is_available?' do
    it "handles availability" do
      silence_warnings do
        expect(test_inst.is_available?(:feature1)).to be_truthy
        expect(test_inst.is_available?(:feature2)).to be_falsey
      end
    end

    it "handles supports" do
      silence_warnings do
        expect(test_inst.is_available?(:feature3)).to be_truthy
        expect(test_inst.is_available?(:feature4)).to be_falsey
      end
    end
  end

  describe '.is_available_now_error_message' do
    it "handles availability" do
      silence_warnings do
        expect(test_inst.is_available_now_error_message(:feature1)).to be_nil
        expect(test_inst.is_available_now_error_message(:feature2)).not_to be_nil
      end
    end

    it "handles supports" do
      silence_warnings do
        expect(test_inst.is_available_now_error_message(:feature3)).to be_nil
        expect(test_inst.is_available_now_error_message(:feature4)).not_to be_nil
      end
    end
  end

  describe '.supports?' do
    it "handles availability" do
      expect(test_inst.supports?(:feature1)).to be_truthy
      expect(test_inst.supports?(:feature2)).to be_falsey
    end

    it "handles supports" do
      expect(test_inst.supports?(:feature3)).to be_truthy
      expect(test_inst.supports?(:feature4)).to be_falsey
    end
  end

  describe '.unsupported_reason' do
    it "handles availability" do
      expect(test_inst.unsupported_reason(:feature1)).to be_nil
      expect(test_inst.unsupported_reason(:feature2)).not_to be_nil
    end

    it "handles supports" do
      expect(test_inst.unsupported_reason(:feature3)).to be_nil
      expect(test_inst.unsupported_reason(:feature4)).not_to be_nil
    end
  end
end
