require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. util})))
$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. util extensions})))
require 'miq-syntax-checker'
require 'miq-string'

describe MiqSyntaxChecker do
  context "#check" do
    it "valid" do
      result = described_class.check "this.is.valid.syntax"
      result.should be_valid

      result = described_class.check "i = 1"
      result.should be_valid
    end

    it "invalid" do
      result = described_class.check "this.is -> not -> valid $ruby:syntax"
      result.should_not be_valid
    end
  end

  it "#error_line, #error_text" do
    result = described_class.check "line(1).is.okay\nline(2) is not :("
    result.error_line.should == 2
    result.error_text.should =~ /syntax error/
  end
end
