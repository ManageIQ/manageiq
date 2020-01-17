RSpec.describe OpenscapResult do
  let(:openscap_result) { described_class.new(:id => 17) }
  context "#html" do
    it "raises exception if there is no blob" do
      expect { openscap_result.html }.to raise_error(NoMethodError)
    end

    it "extracts the arf html" do
      openscap_result.binary_blob = BinaryBlob.new(:binary => "BLOB")
      arf = double
      expect(arf).to receive(:html)
      expect_any_instance_of(described_class).to receive(:with_openscap_arf).and_yield(arf)
      openscap_result.html
    end
  end

  context "#create_results" do
    it "parses results" do
      rule_results = [
        [1, double(:result => 'result_1')],
        [2, double(:result => 'result_2')]]

      benchmark_items = {1 => double(:severity => 'Bad', :idents => [], :title => "Bad"),
                         2 => double(:severity => 'Not That Bad', :idents => [], :title => "Not That Bad")}

      openscap_result.instance_eval { create_results(rule_results, benchmark_items) }
      expect(openscap_result.openscap_rule_results[0]).to have_attributes(
        :openscap_result_id => 17,
        :name               => '1',
        :result             => "result_1",
        :title              => "Bad",
        :severity           => "Bad")
      expect(openscap_result.openscap_rule_results[1]).to have_attributes(
        :openscap_result_id => 17,
        :name               => '2',
        :result             => "result_2",
        :title              => "Not That Bad",
        :severity           => "Not That Bad")
    end
  end
end
