
$:.push(File.dirname(__FILE__))

require "handsoap"
require "RcuTypes"

class RcuService < Handsoap::Service

	Handsoap.http_driver = :HTTPClient

	DEFAULT_NAMESPACE = 'http://server.kamino.netapp.com/'

	def initialize(ep)
		super
		setNameSpace(DEFAULT_NAMESPACE)
	end
	
	def createClones(arg0)
		response = invoke("n1:createClones") do |message|
			message.add "arg0" do |i|
				marshalObj(i, arg0)
			end
		end
		return(parse_response(response, 'createClonesResponse')['return'])
	end
	
	def createDatastore(arg0, arg1)
		response = invoke("n1:createDatastore") do |message|
			message.add "arg0" do |i|
				marshalObj(i, arg0)
			end
			message.add "arg1" do |i|
				marshalObj(i, arg1)
			end
		end
		return(parse_response(response, 'createDatastoreResponse')['return'])
	end
	
	def destroyDatastore(arg0, arg1)
		response = invoke("n1:destroyDatastore") do |message|
			message.add "arg0" do |i|
				marshalObj(i, arg0)
			end
			message.add "arg1" do |i|
				marshalObj(i, arg1)
			end
		end
		return(parse_response(response, 'destroyDatastoreResponse')['return'])
	end
	
	def getMoref(arg0, arg1, arg2)
		response = invoke("n1:getMoref") do |message|
			message.add "arg0",		arg0 do |i|
				i.set_attr "xsi:type", "xsd:string"
			end
			message.add "arg1",		arg1 do |i|
				i.set_attr "xsi:type", "xsd:string"
			end
			message.add "arg2" do |i|
				marshalObj(i, arg2)
			end
		end
		return(parse_response(response, 'getMorefResponse')['return'])
	end
	
	def getVmFiles(arg0, arg1)
		response = invoke("n1:getVmFiles") do |message|
			message.add "arg0", arg0
			message.add "arg1" do |i|
				marshalObj(i, arg1)
			end
		end
		return(parse_response(response, 'getVmFilesResponse')['return'])
	end
	
	def getVms(arg0, arg1)
		response = invoke("n1:getVms") do |message|
			message.add "arg0", arg0 if arg0
			message.add "arg1" do |i|
				marshalObj(i, arg1)
			end
		end
		rv = parse_response(response, 'getVmsResponse')['return']
		return rv if rv.kind_of?(Array)
		return [ rv ] unless rv.nil?
		return []
	end
	
	def resizeDatastore(arg0, arg1)
		response = invoke("n1:resizeDatastore") do |message|
			message.add "arg0" do |i|
				marshalObj(i, arg0)
			end
			message.add "arg1" do |i|
				marshalObj(i, arg1)
			end
		end
		return(parse_response(response, 'resizeDatastoreResponse')['return'])
	end

	private

	def setNameSpace(ns)
		@ns = { 'n1' => ns }
		on_create_document do |doc|
			doc.alias 'n1', ns
			env = doc.find("Envelope")
			env.set_attr "xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"
		end
	end

	def marshalObj(node, obj)
		if obj.kind_of? Array
            obj.each do |v|
				marshalObj(node, v)
			end
        elsif obj.kind_of? RcuHash
            obj.each do |k, v|
				if v.kind_of? Array
					v.each do |av|
						node.add "#{k}" do |i|
							marshalObj(i, av)
						end
					end
				else
					node.add "#{k}" do |i|
						marshalObj(i, v)
					end
				end
			end
		elsif obj.kind_of? RcuVal
			node.set_attr "xsi:type", obj.xsiType
			node.set_value(obj)
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

		obj = RcuHash.new

		node.children.each do |c|
			next if c.blank?

			if (v = obj[c.name])
				unless v.kind_of?(Array)
					obj[c.name] = RcuArray.new
					obj[c.name] << v
					v = obj[c.name]
				end
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
