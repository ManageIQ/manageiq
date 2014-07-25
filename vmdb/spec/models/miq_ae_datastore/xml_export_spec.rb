require "spec_helper"

describe MiqAeDatastore::XmlExport do
  describe ".to_xml" do
    let(:custom_button) { active_record_instance_double("CustomButton") }
    let(:custom_buttons) { [custom_button] }
    let(:miq_ae_class1) { active_record_instance_double("MiqAeClass", :fqname => "z") }
    let(:miq_ae_class2) { active_record_instance_double("MiqAeClass", :fqname => "a") }
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
      MiqAeClass.stub(:all).and_return(miq_ae_classes)
      CustomButton.stub(:all).and_return(custom_buttons)
    end

    it "sorts the miq ae classes and returns the correct xml" do
      miq_ae_class2.should_receive(:to_export_xml) do |options|
        options[:builder].target!.should eq <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<MiqAeDatastore version="1.0">
        XML
        options[:skip_instruct].should be_true
        options[:indent].should eq(2)
        options[:builder].class2
      end

      miq_ae_class1.should_receive(:to_export_xml) do |options|
        options[:builder].target!.should eq <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<MiqAeDatastore version="1.0">
  <class2/>
        XML
        options[:skip_instruct].should be_true
        options[:indent].should eq(2)
        options[:builder].class1
      end

      custom_button.should_receive(:to_export_xml) do |options|
        options[:builder].target!.should eq <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<MiqAeDatastore version="1.0">
  <class2/>
  <class1/>
        XML
        options[:skip_instruct].should be_true
        options[:indent].should eq(2)
        options[:builder].custom_button
      end

      expect(MiqAeDatastore::XmlExport.to_xml).to eq(expected_xml)
    end
  end
end
