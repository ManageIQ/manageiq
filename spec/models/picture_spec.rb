require "spec_helper"

describe Picture do
  subject { FactoryGirl.build :picture }

  it "auto-creates needed directory" do
    File.directory?(described_class.directory).should be_true
  end

  it "#content" do
    subject.content.should == nil
    expected = "FOOBAR"
    subject.content         = expected.dup
    subject.content.should == expected
  end

  context "#extension" do
    it "on new record" do
      subject.extension.should == nil
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
      subject.extension.should == nil
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
    subject.size.should    == 0
    expected = "FOOBAR"
    subject.content         = expected.dup
    subject.size.should    == expected.length
  end

  context "#basename" do
    it "fails when record is new" do
      lambda { subject.filename }.should raise_error
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

  context "#sync_to_disk?" do
    before(:each) do
      subject.extension = "png"
      subject.save
    end

    it "is true when file does not exist" do
      File.stub(:file?).with(subject.filename).and_return(false)
      subject.sync_to_disk?.should be_true
    end

    it "is true when file is the wrong size" do
      File.stub(:file?).with(subject.filename).and_return(true)
      File.stub(:size).with(subject.filename).and_return(12345)
      subject.sync_to_disk?.should be_true
    end

    it "is true when file content is the wrong md5" do
      content = "FOOBAR"
      subject.content = content
      File.stub(:file?).with(subject.filename).and_return(true)
      File.stub(:size).with(subject.filename).and_return(subject.size)
      Digest::MD5.any_instance.stub(:file).and_return(Digest::MD5.new)
      Digest::MD5.any_instance.stub(:hexdigest).and_return("12345")
      subject.sync_to_disk?.should be_true
    end

    it "is false when metadata matches" do
      content = "FOOBAR"
      subject.content = content
      File.stub(:file?).with(subject.filename).and_return(true)
      File.stub(:size).with(subject.filename).and_return(subject.size)
      Digest::MD5.any_instance.stub(:file).and_return(Digest::MD5.new)
      Digest::MD5.any_instance.stub(:hexdigest).and_return(subject.md5)
      subject.sync_to_disk?.should be_false
    end
  end

  context "#sync_to_disk" do
    before(:each) do
      subject.extension = "png"
      subject.save
    end

    it "when #sync_to_disk? is false" do
      subject.stub(:sync_to_disk?).and_return false
      File.should_receive(:open).never
      subject.sync_to_disk
    end

    it "when #sync_to_disk? is true" do
      subject.stub(:sync_to_disk?).and_return true
      File.should_receive(:open).once.with(subject.filename, "wb")
      subject.sync_to_disk
    end
  end

  context ".sync_to_disk" do
    it "when passing invalid id" do
      lambda { described_class.sync_to_disk(7) }.should raise_error
    end

    it "when passing a single valid id" do
      subject.save
      described_class.any_instance.should_receive(:sync_to_disk).once
      described_class.sync_to_disk(subject.id)
    end

    it "when passing an array of valid id" do
      subject.save
      Picture.stub(:find).and_return(subject)
      subject.should_receive(:sync_to_disk).twice
      described_class.sync_to_disk([subject.id, subject.id])
    end

    it "when passing a single valid object" do
      subject.save
      described_class.any_instance.should_receive(:sync_to_disk).once
      described_class.sync_to_disk(subject)
    end

    it "when passing an array of valid object" do
      subject.save
      Picture.stub(:find).and_return(subject)
      subject.should_receive(:sync_to_disk).twice
      described_class.sync_to_disk([subject, subject.id])
    end
  end
end
