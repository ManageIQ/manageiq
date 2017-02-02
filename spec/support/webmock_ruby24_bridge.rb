# Ruby 2.4.0 removed the closed? check in the conditional in: s.close if !s.closed?
# Webmock was changed to add close to StubSocket along with another change.
# https://github.com/ruby/ruby/commit/f845a9ef76c0195254ded79c85c24332534f4057
# https://github.com/bblimke/webmock/commit/8f2176a1fa75374df55b87d782e08ded673a75b4
# WebMock 2.3.1+ fixed this.
# We should upgrade webmock but that requires some re-recording of cassettes (I think)
# and maybe other things.
if WebMock::VERSION < "2.3.1"
  class StubSocket
    def close
    end
  end
else
  warn "Remove me: #{__FILE__}:#{__LINE__}. WebMock 2.3.1+ fixed the issue with ruby 2.4.0 by adding StubSocket#close."
end
