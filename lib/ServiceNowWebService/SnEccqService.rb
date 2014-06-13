
$:.push(File.dirname(__FILE__))

require "handsoap"
require "ServiceNowTypes"

class SnEccqService < Handsoap::Service

	Handsoap.http_driver = :HTTPClient

	DEFAULT_NAMESPACE = 'http://www.service-now.com/ecc_queue'

	def initialize(ep)
		super
		setNameSpace(DEFAULT_NAMESPACE)
	end

	def insert(agent, queue, topic, name, source, payload)
		pe = Handsoap::XmlMason::Element.new(nil, nil, 'notification')
		payload.each { |k, v| pe.add k, v }

		response = invoke("n1:insert") do |message|
			message.add "n1:agent",		agent do |i|
				i.set_attr "xsi:type", "xsd:string"
			end
			message.add "n1:queue",		queue do |i|
				i.set_attr "xsi:type", "xsd:string"
			end
			message.add "n1:topic",		topic do |i|
				i.set_attr "xsi:type", "xsd:string"
			end
			message.add "n1:name",		name do |i|
				i.set_attr "xsi:type", "xsd:string"
			end
			message.add "n1:source",	source do |i|
				i.set_attr "xsi:type", "xsd:string"
			end
			message.add "n1:payload",	pe.to_s do |i|
				i.set_attr "xsi:type", "xsd:string"
			end
		end
		return(parse_response(response, 'insertResponse'))
	end

	private

	def setNameSpace(ns)
		@ns = { 'n1' => ns }
		on_create_document do |doc|
			doc.alias 'n1', ns
			doc.find("Envelope").set_attr "xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"
		end
	end

	def marshalObj(node, obj)
		if obj.kind_of? Array
			puts "Array"
            obj.each do |v|
				marshalObj(node, v)
			end
        elsif obj.kind_of? EvmsHash
            obj.each do |k, v|
				if v.kind_of? Array
					v.each do |av|
						node.add "n1:#{k}" do |i|
							marshalObj(i, av)
						end
					end
				else
					node.add "n1:#{k}" do |i|
						marshalObj(i, v)
					end
				end
			end
        else
            node.set_value(obj)
		end
	end

	def parse_response(response, rType)
		unless response.document.nil?
			node = response.document.xpath("//snow:#{rType}", 'snow' => DEFAULT_NAMESPACE).first || response.document.xpath("//#{rType}").first
			raise "Invalid Response - Node '#{rType}' not found in #{response.document.inspect}" if node.nil?
			ur = unmarshal_response(node)
			return(ur)
		end

		http_body = response.instance_variable_get("@http_body")
		raise Handsoap::Fault.new("SNAuthFaultCode", "Authentication Failure", http_body)	 if http_body.include?("This request requires HTTP authentication")
		raise http_body
	end

	def unmarshal_response(node)
		return(node.text) if node.text?

		if node.children.length == 1 && (c = node.child) && c.text?
			return String.new(c.text)
		end

		obj = SnsHash.new

		node.children.each do |c|
			next if c.blank?

			if (v = obj[c.name])
				v = obj[c.name] = SnsArray.new { |a| a << v } unless v.kind_of?(Array)
			end

			if v.kind_of?(Array)
				obj[c.name] << unmarshal_response(c)
			else
				obj[c.name] = unmarshal_response(c)
			end
		end
		return(obj)
	end

end
