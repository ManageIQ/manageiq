RSpec.describe PdfGenerator do
  let(:generator) do
    double("PdfGenerator subclass", :available? => true, :pdf_from_string => "pdf-data")
  end

  describe ".new" do
    it "will return the detected subclass" do
      expect(PdfGenerator.new.class).to_not eq PdfGenerator
    end

    it "can be called on a subclass" do
      expect(NullPdfGenerator.new.class).to eq NullPdfGenerator
    end
  end

  describe "availablity" do
    subject { PdfGenerator }

    before do
      expect(PdfGenerator).to receive_messages(:instance => generator)
    end

    context "when available" do
      it { is_expected.to be_available }
    end

    context "when not available" do
      before do
        expect(PdfGenerator.instance).to receive(:available?).and_return(false)
      end

      it { is_expected.to_not be_available }
    end
  end

  describe ".pdf_from_string" do
    subject { generator.pdf_from_string("html", "pdf_report.css") }

    it { is_expected.to eq "pdf-data" }
  end
end
