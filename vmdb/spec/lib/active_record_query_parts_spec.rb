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
end
