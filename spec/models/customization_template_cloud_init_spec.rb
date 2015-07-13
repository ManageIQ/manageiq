require "spec_helper"

describe CustomizationTemplateCloudInit do
  context "#default_filename" do
    it "should be user-data.txt" do
      described_class.new.default_filename.should == 'user-data.txt'
    end
  end
end
