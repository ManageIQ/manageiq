require 'util/extensions/miq-file'

describe 'MIQFile' do
  context 'path_to_uri' do
    let(:hostname) { MiqSockUtil.getFullyQualifiedDomainName }

    it 'is defined and returns a string' do
      expect(File).to respond_to(:path_to_uri)
      expect(File.path_to_uri('foo')).to be_kind_of(String)
    end

    it 'returns the expected result' do
      expect(File.path_to_uri('foo')).to eql("file://#{hostname}/foo")
      expect(File.path_to_uri('foo/bar')).to eql("file://#{hostname}/foo/bar")
      expect(File.path_to_uri('foo/bar-stuff')).to eql("file://#{hostname}/foo/bar-stuff")
      expect(File.path_to_uri('foo/C:/bar')).to eql("file://#{hostname}/foo/C:/bar")
      expect(File.path_to_uri('foo/[bar]')).to eql("file://#{hostname}/foo/%5Bbar%5D")
    end

    it 'accepts an optional hostname and returns the expected result' do
      hostname = 'dell-r410-01.manageiqwin.lab.example.com'
      expect(File.path_to_uri('foo', hostname)).to eql("file://#{hostname}/foo")
      expect(File.path_to_uri('foo/bar', hostname)).to eql("file://#{hostname}/foo/bar")
      expect(File.path_to_uri('foo/bar-stuff', hostname)).to eql("file://#{hostname}/foo/bar-stuff")
      expect(File.path_to_uri('foo/C:/bar', hostname)).to eql("file://#{hostname}/foo/C:/bar")
      expect(File.path_to_uri('foo/[bar]', hostname)).to eql("file://#{hostname}/foo/%5Bbar%5D")
    end

    it 'handles an IPv6 hostname as expected' do
      hostname = '::1'
      expect(File.path_to_uri('foo', hostname)).to eql("file://[#{hostname}]/foo")
    end

    it 'requires at least one argument' do
      expect { File.path_to_uri }.to raise_error(ArgumentError)
    end
  end
end
