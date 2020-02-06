require "stringio"

RSpec.describe SysprepFile do
  let(:good_ini) { "[section1]\n; some comment on section1\nvar1 = foo\nvar2 = bar" }
  let(:bad_ini)  { "; some comment on section1\nvar1_foo\nINI_DATA" }
  let(:good_xml) { "<?xml version=\"1.0\"?><unattend/>" }
  let(:bad_xml)  { "<?xml version=\"1.0\"?><bad_root_name/>" }

  context "valid inputs" do
    ["INI", "XML"].each do |type|
      context type.to_s do
        it("allows string")    { expect(described_class.new(send("good_#{type.downcase}"))).to be_kind_of(SysprepFile) }
        it("allows IO stream") { expect(described_class.new(StringIO.new(send("good_#{type.downcase}")))).to be_kind_of(SysprepFile) }
      end
    end
  end

  context "invalid inputs raise errors" do
    it("INI") { expect { described_class.new(bad_ini) }.to raise_error(StandardError, "Invalid INI file contents detected. Could not parse line: \"var1_foo\"") }
    it("XML") { expect { described_class.new(bad_xml) }.to raise_error(RuntimeError, "Invalid XML file contents detected.") }
  end
end
