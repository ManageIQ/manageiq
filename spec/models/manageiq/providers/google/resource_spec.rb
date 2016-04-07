describe ManageIQ::Providers::Google::Resource do
  context "created with disk uri" do
    let(:resource) do
      uri = 'https://content.googleapis.com/compute/v1/projects/manageiq-dev/zones/us-central1-a/disks/foobar'
      described_class.new(uri)
    end

    it 'disk? is true' do
      expect(resource.disk?).to be(true)
    end
  end

  context 'created with image uri' do
    let(:resource) do
      uri = 'https://content.googleapis.com/compute/v1/projects/manageiq-dev/global/images/family/centos'
      described_class.new(uri)
    end

    it 'image? is true' do
      expect(resource.image?).to be(true)
    end
  end

  context 'created with snapshot uri' do
    let(:resource) do
      uri = 'https://content.googleapis.com/compute/v1/projects/manageiq-dev/global/snapshots/dev-snapshot-20160324'
      described_class.new(uri)
    end

    it 'snapshot? is true' do
      expect(resource.snapshot?).to be(true)
    end
  end

  context 'created with nil uri' do
    let(:resource) { described_class.new(nil) }

    it 'unknown? is true' do
      expect(resource.unknown?).to be(true)
    end
  end

  context 'created with empty uri' do
    let(:resource) { described_class.new("") }

    it 'unknown? is true' do
      expect(resource.unknown?).to be(true)
    end
  end

  context 'created with path of no depth' do
    let(:resource) { described_class.new("somepath") }

    it 'unknown? is true' do
      expect(resource.unknown?).to be(true)
    end
  end

  context 'created with partial resource path' do
    let(:resource) { described_class.new("compute/v1/projects/manageiq-dev/zones/us-central1-a/disks/foobar") }

    it 'has correct type' do
      expect(resource.disk?).to be(true)
    end
  end

  context 'created with even more partial resource path' do
    let(:resource) { described_class.new("projects/manageiq-dev/zones/us-central1-a/disks/foobar") }

    it 'has correct type' do
      expect(resource.disk?).to be(true)
    end
  end
end
