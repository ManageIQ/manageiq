module RemoteConsole
  module ClientAdapter
    # This module contains adapters for the remote console client connections
    def self.new(record, socket)
      case record.protocol
      when 'vnc'
        RegularSocket.new(record, socket)
      when 'spice'
        record.ssl ? SSLSocket.new(record, socket) : RegularSocket.new(record, socket)
      when 'webmks'
        WebMKS.new(record, socket)
      when 'webmks-uint8utf8'
        WebMKSLegacy.new(record, socket)
      else
        raise NotImplementedError, "Support for #{record.protocol} remote consoles is not implemented!"
      end
    end
  end
end
