require_relative '../../bundler_setup'
require 'httpclient'

# body = %q{<?xml version="1.0" encoding="UTF-8"?><soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><insert xmlns="http://www.service-now.com/"><agent xsi:type="xsd:string">Rich</agent><queue xsi:type="xsd:string">input</queue><topic xsi:type="xsd:string">Open Incident</topic><name xsi:type="xsd:string">admin</name><source xsi:type="xsd:string">70.91.104.157</source><payload xsi:type="xsd:string">&lt;notification&gt;&lt;id&gt;arg0&lt;/id&gt;&lt;category&gt;arg1&lt;/category&gt;&lt;notify&gt;arg2&lt;/notify&gt;&lt;severity&gt;arg3&lt;/severity&gt;&lt;short_description&gt;arg4&lt;/short_description&gt;&lt;description&gt;arg5&lt;/description&gt;&lt;/notification&gt;</payload></insert></soap:Body></soap:Envelope>}
# body = %q{<?xml version="1.0" ?><env:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" env:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Body><insert xmlns="http://www.service-now.com/"><agent xsi:type="xsd:string">Rich</agent><queue xsi:type="xsd:string">input</queue><topic xsi:type="xsd:string">Open Incident</topic><name xsi:type="xsd:string">admin</name><source xsi:type="xsd:string">70.91.104.157</source><payload xsi:type="xsd:string">&lt;notification&gt;&lt;id&gt;arg0&lt;/id&gt;&lt;category&gt;arg1&lt;/category&gt;&lt;notify&gt;arg2&lt;/notify&gt;&lt;severity&gt;arg3&lt;/severity&gt;&lt;short_description&gt;arg4&lt;/short_description&gt;&lt;description&gt;arg5&lt;/description&gt;&lt;/notification&gt;</payload></insert></env:Body></env:Envelope>}
body = %q{<?xml version='1.0' ?><soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Header /><soap:Body><n1:insert xmlns:n1="http://www.service-now.com/ecc_queue"><n1:agent xsi:type="xsd:string">Rich</n1:agent><n1:queue xsi:type="xsd:string">input</n1:queue><n1:topic xsi:type="xsd:string">Open Incident</n1:topic><n1:name xsi:type="xsd:string">admin</n1:name><n1:source xsi:type="xsd:string">70.91.104.157</n1:source><n1:payload xsi:type="xsd:string">&amp;lt;notification&amp;gt;&amp;lt;id&amp;gt;arg0&amp;lt;/id&amp;gt;&amp;lt;category&amp;gt;arg1&amp;lt;/category&amp;gt;&amp;lt;notify&amp;gt;arg2&amp;lt;/notify&amp;gt;&amp;lt;severity&amp;gt;arg3&amp;lt;/severity&amp;gt;&amp;lt;short_description&amp;gt;arg4&amp;lt;/short_description&amp;gt;&amp;lt;description&amp;gt;arg5&amp;lt;/description&amp;gt;&amp;lt;/notification&amp;gt;</n1:payload></n1:insert></soap:Body></soap:Envelope>}
	
http_client = HTTPClient.new
http_client.ssl_config.verify_mode		= OpenSSL::SSL::VERIFY_NONE
# http_client.ssl_config.verify_callback	= method(:verify_callback).to_proc
http_client.receive_timeout				= @receiveTimeout

http_client.set_auth nil, 'itil', 'itil'
# http_client.set_proxy_auth @username, @password
# headers['Authorization'] = "Basic " + Base64.encode64("#{@username}:#{@password}").chomp
http_client.debug_dev = $stdout

headers = {
	"Content-Type"	=> "text/xml;charset=UTF-8",
	"SOAPAction"	=> 'insert',
	'User-Agent'	=> "ManageIQ/EVM"
}

uri = 'https://manageiqdev.service-now.com/ecc_queue.do?SOAP'

response = http_client.post(uri, body, headers)
