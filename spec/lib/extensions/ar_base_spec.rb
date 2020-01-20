RSpec.describe "ar_base extension" do
  context "with a test class" do
    let(:test_class) do
      Class.new(ActiveRecord::Base) do
        def self.name; "TestClass"; end
      end
    end

    it ".vacuum" do
      expect(test_class.connection).to receive(:vacuum_analyze_table).and_return(double(:result_status => 1))
      test_class.vacuum
    end
  end
end
