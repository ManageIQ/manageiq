describe Picture do
  subject { FactoryGirl.build :picture }

  before do
    subject.content = 'foo'
  end

  it "auto-creates needed directory" do
    expect(File.directory?(described_class.directory)).to be_truthy
  end

  context "#content" do
    it 'returns expected content' do
      expected = "FOOBAR"
      subject.content = expected.dup
      expect(subject.content).to eq(expected)
    end

    it 'requires content' do
      subject.content = ''
      expect(subject.valid?).to be_falsey
    end
  end

  context "#extension" do
    it "accepts only png, jpg, or svg" do
      expect(subject.extension).to be_nil
      subject.extension = "foo"

      expect(subject.valid?).to be_falsey
      expect(subject.errors.messages).to eq(:extension =>['must be a png, jpg, or svg'])

      subject.extension = "png"
      expect(subject.valid?).to be_truthy

      subject.extension = "jpg"
      expect(subject.valid?).to be_truthy

      subject.extension = "svg"
      expect(subject.valid?).to be_truthy
    end

    it "on new record" do
      expect(subject.extension).to be_nil
      ext = "png"
      subject.extension = ext.dup
      expect(subject.extension).to eq(ext)

      subject.save

      p = described_class.first
      expect(p.extension).to eq(ext)

      subject.reload
      expect(subject.extension).to eq(ext)
    end

    it "on existing record" do
      subject.save

      subject.reload
      expect(subject.extension).to be_nil
      ext = "jpg"
      subject.extension = ext.dup
      expect(subject.extension).to eq(ext)

      subject.save

      p = described_class.first
      expect(p.extension).to eq(ext)

      subject.reload
      expect(subject.extension).to eq(ext)
    end
  end

  it "#size" do
    expected = "FOOBAR"
    subject.content = expected.dup
    expect(subject.size).to eq(expected.length)
  end

  context "#basename" do
    it "fails when record is new" do
      expect { subject.filename }.to raise_error(RuntimeError, /must have a numeric id/)
    end

    context "works when record is saved" do
      it "without extension" do
        subject.save
        expect(subject.basename).to eq("#{subject.compressed_id}.")
      end

      it "with extension" do
        subject.extension = "png"
        subject.save
        expect(subject.basename).to eq("#{subject.compressed_id}.#{subject.extension}")
      end
    end
  end

  it "#filename" do
    basename = "foo.bar"
    allow(subject).to receive(:basename).and_return(basename)
    expect(subject.filename).to eq(File.join(Picture.directory, basename))
  end

  it "#url_path" do
    basename = "foo.bar"
    allow(subject).to receive(:basename).and_return(basename)
    expect(subject.url_path).to eq("/pictures/#{basename}")
  end
end
