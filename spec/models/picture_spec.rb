RSpec.describe Picture do
  subject { FactoryBot.build(:picture) }

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
    it 'is required' do
      subject.extension = nil
      expect(subject.valid?).to be_falsey
      expect(subject.errors.messages).to eq(:extension => ["can't be blank", "must be a png, jpg, or svg"])
    end

    it "accepts only png, jpg, or svg" do
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
      it "with extension" do
        subject.extension = "png"
        subject.save
        expect(subject.basename).to eq("#{subject.id}.#{subject.extension}")
      end
    end
  end

  context '.create_from_base64' do
    let(:attributes) do
      {
        :extension => 'png',
        :content   => 'aW1hZ2U='
      }
    end

    it 'creates a picture' do
      expect do
        Picture.create_from_base64(attributes)
      end.to change(Picture, :count).by(1)
    end

    it 'requires valid base64' do
      attributes[:content] = 'bogus'
      expect do
        Picture.create_from_base64(attributes)
      end.to raise_error(StandardError, 'invalid base64')
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
