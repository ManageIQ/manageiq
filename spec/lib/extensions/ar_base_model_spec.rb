describe "ar_base_model extension" do
  context "with a test class" do
    before(:each) { class ::TestClass < ActiveRecord::Base; end }
    after(:each)  { Object.send(:remove_const, :TestClass) }

    it ".base_model" do
      expect(TestClass.base_model).to eq(TestClass)
    end

    it ".model_suffix" do
      expect(TestClass.model_suffix).to eq("")
    end

    context "with a subclass" do
      before(:each) { class ::TestClassFoo < ::TestClass; end }
      after(:each)  { Object.send(:remove_const, :TestClassFoo) }

      it ".base_model" do
        expect(TestClassFoo.base_model).to eq(TestClass)
      end

      it ".model_suffix" do
        expect(TestClassFoo.model_suffix).to eq("Foo")
      end
    end
  end
end
