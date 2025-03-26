RSpec.describe "ar_base_model extension" do
  before do
    class TestClass < ActiveRecord::Base; end
    class TestClassSub1 < TestClass; end
    class TestClassSub2 < TestClass
      def self.base_model; TestClassSub2; end
    end
    class TestClassSub2Sub2A < TestClassSub2; end
  end

  after do
    Object.send(:remove_const, :TestClassSub2Sub2A)
    Object.send(:remove_const, :TestClassSub2)
    Object.send(:remove_const, :TestClassSub1)
    Object.send(:remove_const, :TestClass)
  end

  it ".base_model" do
    expect(TestClass.base_model).to          eq(TestClass)
    expect(TestClassSub1.base_model).to      eq(TestClass)
    expect(TestClassSub2.base_model).to      eq(TestClassSub2)
    expect(TestClassSub2Sub2A.base_model).to eq(TestClassSub2)
  end

  it ".base_model?" do
    expect(TestClass.base_model?).to          eq(true)
    expect(TestClassSub1.base_model?).to      eq(false)
    expect(TestClassSub2.base_model?).to      eq(true)
    expect(TestClassSub2Sub2A.base_model?).to eq(false)
  end

  it ".model_suffix" do
    expect(TestClass.model_suffix).to          eq("")
    expect(TestClassSub1.model_suffix).to      eq("Sub1")
    expect(TestClassSub2.model_suffix).to      eq("")
    expect(TestClassSub2Sub2A.model_suffix).to eq("Sub2A")
  end
end
