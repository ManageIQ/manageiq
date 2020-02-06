RSpec.describe ActiveRecordQueryParts do
  context "glob to sql" do
    it "replaces '*'" do
      expect(described_class.glob_to_sql_like("a*b*c")).to eq("a%b%c")
    end
    it "replaces '?'" do
      expect(described_class.glob_to_sql_like("a?b?c")).to eq("a_b_c")
    end
    it "replaces mixed '?' and '*'" do
      expect(described_class.glob_to_sql_like("a?b*c")).to eq("a_b%c")
    end
    it "works with replacing nothing" do
      expect(described_class.glob_to_sql_like("axbxc")).to eq("axbxc")
    end
  end
end
