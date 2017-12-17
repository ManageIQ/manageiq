describe MiddlewareServer do
  subject(:server) { MiddlewareServer.new }

  describe 'in_domain?' do
    it 'is true if the server is in a group' do
      server.middleware_server_group = MiddlewareServerGroup.new
      expect(server).to be_in_domain
    end

    it 'is false otherwise' do
      expect(server).not_to be_in_domain
    end
  end

  describe 'properties' do
    it 'is empty hash if not defined' do
      expect(server.properties).to eq({})
    end

    it 'can be acessed normally if defined' do
      hash = { 'foo' => 'bar' }
      server.properties = hash
      expect(server.properties).to eq(hash)
    end
  end

  describe '#immutable?' do
    it 'is always true' do
      expect(server).to be_immutable
    end
  end

  describe '#mutable?' do
    it 'is true if not immutable' do
      allow(server).to receive(:immutable?) { false }
      expect(server).to be_mutable
    end

    it 'is false if immutable' do
      allow(server).to receive(:immutable?) { true }
      expect(server).not_to be_mutable
    end
  end
end
