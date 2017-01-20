describe WebsocketDecorator do
  describe '.decorate' do
    let(:pipes) { IO.pipe }
    let(:read) { pipes.first }
    let(:write) { pipes.last }
    let(:foo) { 'abcdefgh' }

    describe 'socket#read_nonblock' do
      subject { described_class.decorate(read, 13) }
      let(:frame) do
        WebSocket::Frame::Outgoing::Server.new(:version => 13, :data => foo, :type => :binary)
      end

      context 'receives a single frame' do
        context 'complete' do
          it 'decodes the frame content' do
            len = write.syswrite(frame.to_s)
            data = subject.read_nonblock(len)
            expect(data).to eq(foo)
          end
        end

        context 'incomplete' do
          it 'returns with an empty string' do
            len = write.syswrite(frame.to_s[0..5])
            data = subject.read_nonblock(len)
            expect(data).to be_empty
          end
        end

        context 'read in multiple passes' do
          it 'eventually decodes the frame content' do
            len = write.syswrite(frame.to_s[0..5])
            data = subject.read_nonblock(len)
            expect(data).to be_empty
            len = write.syswrite(frame.to_s[6..9])
            data = subject.read_nonblock(len)
            expect(data).to eq(foo)
          end
        end
      end

      context 'receives multiple frames' do
        before do
          2.times { write.syswrite(frame.to_s) }
        end

        context 'last one is complete' do
          it 'returns with the decoded and joined data' do
            data = subject.read_nonblock(2 * frame.to_s.length)
            expect(data).to eq([foo, foo].join(''))
          end
        end

        context 'last one is incomplete' do
          it 'returns with the decodable part of data only' do
            len = write.syswrite(frame.to_s[0..5])
            data = subject.read_nonblock(2 * frame.to_s.length + len)
            expect(data).to eq([foo, foo].join(''))
          end
        end
      end
    end

    describe 'socket#write_nonblock' do
      subject { described_class.decorate(write, 13) }

      it 'encapsulates the input in a WS frame' do
        parser = WebSocket::Frame::Incoming::Server.new
        subject.write_nonblock(foo)
        parser << read.read_nonblock(64)
        expect(parser.next.data).to eq(foo)
      end
    end
  end
end
