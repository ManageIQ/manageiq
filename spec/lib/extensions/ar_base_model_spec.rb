RSpec.describe "ar_base_model extension" do
  context "with a test class" do
    let(:test_class) do
      Class.new(ActiveRecord::Base) do
        def self.name; "TestClass"; end
      end
    end

    it ".base_model" do
      expect(test_class.base_model).to eq(test_class)
    end

    it ".model_suffix" do
      expect(test_class.model_suffix).to eq("")
    end

    context "with a subclass" do
      let(:test_class_foo) do
        Class.new(test_class) do
          def self.name; "TestClassFoo"; end
        end
      end

      it ".base_model" do
        expect(test_class_foo.base_model).to eq(test_class)
      end

      it ".model_suffix" do
        expect(test_class_foo.model_suffix).to eq("Foo")
      end
    end
  end
end
