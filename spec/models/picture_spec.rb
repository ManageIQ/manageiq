require "spec_helper"

describe Picture do
  subject { FactoryGirl.build :picture }

  it "auto-creates needed directory" do
    File.directory?(described_class.directory).should be_true
  end

  it "#content" do
    subject.content.should.nil?
    expected = "FOOBAR"
    subject.content         = expected.dup
    subject.content.should == expected
  end

  context "#extension" do
    it "on new record" do
      subject.extension.should.nil?
      ext = "foo"
      subject.extension         = ext.dup
      subject.extension.should == ext

      subject.save

      p = described_class.first
      p.extension.should == ext

      subject.reload
      subject.extension.should == ext
    end

    it "on existing record" do
      subject.save

      subject.reload
      subject.extension.should.nil?
      ext = "foo"
      subject.extension         = ext.dup
      subject.extension.should == ext

      subject.save

      p = described_class.first
      p.extension.should == ext

      subject.reload
      subject.extension.should == ext
    end
  end

  it "#size" do
    subject.size.should == 0
    expected = "FOOBAR"
    subject.content         = expected.dup
    subject.size.should == expected.length
  end

  context "#basename" do
    it "fails when record is new" do
      -> { subject.filename }.should raise_error
    end

    context "works when record is saved" do
      it "without extension" do
        subject.save
        subject.basename.should == "#{subject.compressed_id}."
      end

      it "with extension" do
        subject.extension = "png"
        subject.save
        subject.basename.should == "#{subject.compressed_id}.#{subject.extension}"
      end
    end
  end

  it "#filename" do
    basename = "foo.bar"
    subject.stub(:basename).and_return(basename)
    subject.filename.should == File.join(Picture.directory, basename)
  end

  it "#url_path" do
    basename = "foo.bar"
    subject.stub(:basename).and_return(basename)
    subject.url_path.should == "/pictures/#{basename}"
  end
end
