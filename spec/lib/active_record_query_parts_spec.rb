require "spec_helper"

describe ActiveRecordQueryParts do
  context "regexp" do
    let(:field) { "field" }
    let(:regex) { "%\-[0-9]\.vmdk" }

    it ".regexp" do
      result = described_class.regexp(field, regex)
      expect(result).to eq "#{field} SIMILAR TO '#{regex}'"
    end

    it ".not_regexp" do
      result = described_class.not_regexp(field, regex)
      expect(result).to eq "#{field} NOT SIMILAR TO '#{regex}'"
    end
  end

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
