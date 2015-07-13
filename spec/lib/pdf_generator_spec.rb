require "spec_helper"

describe PdfGenerator do
  context ".new" do
    it "will return the detected subclass" do
      expect(PdfGenerator.new.class).to_not eq PdfGenerator
    end

    it "can be called on a subclass" do
      expect(NullPdfGenerator.new.class).to eq NullPdfGenerator
    end
  end

  def stub_generator_instance
    generator = double("PdfGenerator subclass", :available? => true, :pdf_from_string => "pdf-data")
    PdfGenerator.stub(:instance => generator)
    generator
  end

  context ".available?" do
    it "when available" do
      stub_generator_instance
      expect(PdfGenerator).to be_available
    end

    it "when not available" do
      generator = stub_generator_instance
      generator.stub(:available? => false)
      expect(PdfGenerator).to_not be_available
    end
  end

  it ".pdf_from_string" do
    stub_generator_instance
    expect(PdfGenerator.pdf_from_string("html", "css")).to eq "pdf-data"
  end
end
