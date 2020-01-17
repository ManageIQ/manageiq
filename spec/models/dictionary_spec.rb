RSpec.describe Dictionary do
  context ".gettext" do
    context "with empty text" do
      it("returns an empty string") { expect(described_class.gettext("")).to eq("") }
    end

    context "with nil" do
      it("returns an empty string") { expect(described_class.gettext(nil)).to eq("") }
    end

    context "with text only" do
      it("and not found")         { expect(described_class.gettext("abc")).to                         eq("abc") }
      it("as a column entry")     { expect(described_class.gettext("active")).to                      eq("Active") }
      it("including '__'")        { expect(described_class.gettext("active__abc")).to                 eq("Active (Abc)") }
      it("including '.' and __'") { expect(described_class.gettext("prefix.active__abc")).to          eq("Active (Abc)") }
      it("and a nested key")      { expect(described_class.gettext("availability_zone.total_vms")).to eq("Total Instances") }
    end

    it("with :type option") { expect(described_class.gettext("FileDepotFtp", :type => "model")).to eq("FTP") }

    context "with :notfound option" do
      it("and plain text")  { expect(described_class.gettext("abc",     :notfound => :titleize)).to eq("Abc") }
      it("and '.' in text") { expect(described_class.gettext("abc.def", :notfound => :titleize)).to eq("Def") }

      context "on a virtual column" do
        it("and plain text")  { expect(described_class.gettext("v_abc",     :notfound => :titleize)).to eq("Abc") }
        it("and '.' in text") { expect(described_class.gettext("abc.v_def", :notfound => :titleize)).to eq("Def") }
      end
    end
  end
end
