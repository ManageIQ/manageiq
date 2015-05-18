require "spec_helper"

describe Filesystem do
  context "#contents_displayable?" do
    it "filesystem with missing name is not displayable" do
      filesystem = FactoryGirl.create(:filesystem_conf_file_ascii)
      filesystem.stub(:name).and_return(nil)

      expect(filesystem.contents_displayable?).to be_false
    end

    it "filesystem content bigger than 20k characters is not displayable" do
      filesystem = FactoryGirl.create(:filesystem_conf_file_ascii)
      filesystem.stub(:size).and_return(40_000)

      expect(filesystem.contents_displayable?).to be_false
    end

    it "non MIME .conf ascii file is displayable" do
      filesystem = FactoryGirl.create(:filesystem_conf_file_ascii)

      expect(filesystem.contents_displayable?).to be_true
    end

    it "non MIME .conf file, with non ascii characters is not displayable" do
      filesystem = FactoryGirl.create(:filesystem_conf_file_non_ascii)

      expect(filesystem.contents_displayable?).to be_false
    end

    it "non MIME .conf file, without content is not displayable" do
      filesystem = FactoryGirl.create(:filesystem_conf_file_ascii)
      filesystem.stub(:has_contents?).and_return(false)

      expect(filesystem.contents_displayable?).to be_false
    end

    it "MIME .exe binary file is not displayable" do
      filesystem = FactoryGirl.create(:filesystem_binary_file)

      expect(filesystem.contents_displayable?).to be_false
    end

    it "MIME .txt non binary file is displayable" do
      filesystem = FactoryGirl.create(:filesystem_txt_file)

      expect(filesystem.contents_displayable?).to be_true
    end
  end
end
