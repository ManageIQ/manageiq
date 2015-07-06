require 'rubygems'

require 'soap/rpc/driver'

#########################################################################
# Logging Support for SOAP4R as follows:
# Request and Response Lengths  are logged     with level = INFO
# Request and Response Contents are logged     with level = DEBUG and when $miq_wiredump=true (default)
# SoapFault logs Request and Response Contents with level = ERROR
#########################################################################
if SOAP::VERSION == '1.5.6'
  $miq_wiredump = true
  
  module SOAP
    module RPC
      class Proxy
        def self.request
          @@request
        end
        
        def self.sanitized_request
          sanitize(@@request)
        end

        def self.response
          @@response
        end
        
        def self.sanitize(request)
          request.gsub(/(^.*<n1:password>).*?(<\/n1:password>.*$)/, '\1********\2') 
        end
        
        def route(req_header, req_body, reqopt, resopt)
          req_env = ::SOAP::SOAPEnvelope.new(req_header, req_body)
          unless reqopt[:envelopenamespace].nil?
            set_envelopenamespace(req_env, reqopt[:envelopenamespace])
          end
          reqopt[:external_content] = nil
          conn_data = marshal(req_env, reqopt)
          if ext = reqopt[:external_content]
            mime = MIMEMessage.new
            ext.each do |k, v|
            	mime.add_attachment(v.data)
            end
            mime.add_part(conn_data.send_string + "\r\n")
            mime.close
            conn_data.send_string = mime.content_str
            conn_data.send_contenttype = mime.headers['content-type'].str
          end

          @@request = conn_data.send_string
          $log.info  "SOAP Request:  length=#{@@request.length}"            if $log
          $log.debug "SOAP Request:  #{SOAP::RPC::Proxy.sanitized_request}" if $log && $miq_wiredump

          conn_data = @streamhandler.send(@endpoint_url, conn_data, reqopt[:soapaction])

          @@response = conn_data.receive_string
          $log.info  "SOAP Response: length=#{@@response.length}" if $log
          $log.debug "SOAP Response: #{@@response}" if $log && $miq_wiredump

          if conn_data.receive_string.empty?
            return nil
          end
          unmarshal(conn_data, resopt)
        end
        
      end
    end
    class FaultError < Error
      def initialize(fault)
        @faultcode   = fault.faultcode
        @faultstring = fault.faultstring
        @faultactor  = fault.faultactor
        @detail      = fault.detail

        if $log
                $log.warn "SOAP Request : #{SOAP::RPC::Proxy.sanitized_request}"
                $log.warn "SOAP Response: #{SOAP::RPC::Proxy.response}"
                $log.warn "SOAP FaultError: faultcode=#{@faultcode.text} faultstring=#{@faultstring.text} faultdetail=#{@detail.members.first}:#{@detail.text}"
        end
        super(self.to_s)
      end
    end
  end
end