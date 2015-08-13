require "spec_helper"

describe ApplicationHelper do
  context "::FormTags" do
    describe "#datepicker_input_tag" do
      let(:input) { helper.datepicker_input_tag('id01', Time.at(117_036_184_5).utc) }

      it "sets correct date / time value" do
        expect(input).to include('value="2007-02-01 20:30:45 UTC"')
      end

      it "sets data-provide attribute" do
        expect(input).to include('data-provide="datepicker"')
      end

      it "sets autoclose attribute" do
        expect(input).to include('data-date-autoclose="true"')
      end

      it "sets date-format attribute" do
        expect(input).to include('data-date-format=')
      end

      it "sets date-language attribute" do
        expect(input).to include('data-date-language=')
      end
    end
  end
end
