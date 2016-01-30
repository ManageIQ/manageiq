require 'util/miq-syntax-checker'
require 'util/extensions/miq-string'

describe MiqSyntaxChecker do
  context "#check" do
    it "valid" do
      result = described_class.check "this.is.valid.syntax"
      expect(result).to be_valid

      result = described_class.check "i = 1"
      expect(result).to be_valid
    end

    it "invalid" do
      result = described_class.check "this.is -> not -> valid $ruby:syntax"
      expect(result).not_to be_valid
    end
  end

  it "#error_line, #error_text" do
    result = described_class.check "line(1).is.okay\nline(2) is not :("
    expect(result.error_line).to eq(2)
    expect(result.error_text).to match(/syntax error/)
  end
end
