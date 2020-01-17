RSpec.describe MiqAeValue do
  describe "#to_export_xml" do
    let(:miq_ae_value) do
      described_class.new(
        :ae_field    => ae_field,
        :created_on  => Time.now,
        :id          => 123,
        :instance_id => 321,
        :updated_by  => "me",
        :updated_on  => Time.now,
        :value       => value
      )
    end

    let(:ae_field) { MiqAeField.new(:name => "ae_field") }

    context "when the value is blank" do
      let(:value) { nil }
      let(:expected_xml) do
        <<-XML
<MiqAeField name="ae_field"><![CDATA[]]></MiqAeField>
        XML
      end

      it "wraps the value in CDATA" do
        expect(miq_ae_value.to_export_xml).to eq(expected_xml.chomp)
      end
    end

    context "when the value is not blank" do
      let(:value) { "value" }
      let(:expected_xml) do
        <<-XML
<MiqAeField name="ae_field">value</MiqAeField>
        XML
      end

      it "uses the value" do
        expect(miq_ae_value.to_export_xml).to eq(expected_xml.chomp)
      end
    end
  end
end
