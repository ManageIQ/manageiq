
$:.push(File.dirname(__FILE__))

require "handsoap"
require "EvmTypes"

class EvmService < Handsoap::Service
			
	Handsoap.http_driver = :HTTPClient
		
	def initialize(ep)
		super
		setNameSpace('urn:ActionWebService')
	end
	
	def evmProvisionRequest(param0, param1)
		response = invoke("n1:EVMProvisionRequest") do |message|
			message.add "n1:param0", param0
			message.add "n1:param1", param1
		end
		return(parse_response(response, 'EVMProvisionRequestResponse')['return'] == 'true')
	end
	
	private
	
	def setNameSpace(ns)
		@ns = { 'n1' => ns }
		on_create_document do |doc|
			doc.alias 'n1', ns
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
		node = response.document.xpath("//n1:#{rType}", @ns).first
		ur = unmarshal_response(node)
		return(ur)
	end
	
	def unmarshal_response(node)
		return(node.text) if node.text?
		
		if node.children.length == 1 && (c = node.child) && c.text?
			return String.new(c.text)
		end
		
		obj = EvmsHash.new
		
		node.children.each do |c|
			next if c.blank?
			
			if (v = obj[c.name])
				v = obj[c.name] = EvmsArray.new { |a| a << v } unless v.kind_of?(Array)
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
