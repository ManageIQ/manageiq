describe MiqAeDatastore::XmlExport do
  describe ".to_xml" do
    let(:custom_button) { double("CustomButton") }
    let(:custom_buttons) { [custom_button] }
    let(:miq_ae_class1) { double("MiqAeClass", :fqname => "z") }
    let(:miq_ae_class2) { double("MiqAeClass", :fqname => "a") }
    let(:miq_ae_classes) { [miq_ae_class1, miq_ae_class2] }

    let(:expected_xml) do
      <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<MiqAeDatastore version="1.0">
  <class2/>
  <class1/>
  <custom_button/>
</MiqAeDatastore>
      XML
    end

    before do
      # Populate the doubles *before* we start messing with .all
      miq_ae_classes
      custom_buttons

      allow(MiqAeClass).to receive(:all).and_return(miq_ae_classes)
      allow(CustomButton).to receive(:all).and_return(custom_buttons)
    end

    it "sorts the miq ae classes and returns the correct xml" do
      expect(miq_ae_class2).to receive(:to_export_xml) do |options|
        expect(options[:builder].target!).to eq <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<MiqAeDatastore version="1.0">
        XML
        expect(options[:skip_instruct]).to be_truthy
        expect(options[:indent]).to eq(2)
        options[:builder].class2
      end

      expect(miq_ae_class1).to receive(:to_export_xml) do |options|
        expect(options[:builder].target!).to eq <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<MiqAeDatastore version="1.0">
  <class2/>
        XML
        expect(options[:skip_instruct]).to be_truthy
        expect(options[:indent]).to eq(2)
        options[:builder].class1
      end

      expect(custom_button).to receive(:to_export_xml) do |options|
        expect(options[:builder].target!).to eq <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<MiqAeDatastore version="1.0">
  <class2/>
  <class1/>
        XML
        expect(options[:skip_instruct]).to be_truthy
        expect(options[:indent]).to eq(2)
        options[:builder].custom_button
      end

      expect(MiqAeDatastore::XmlExport.to_xml).to eq(expected_xml)
    end
  end
end
