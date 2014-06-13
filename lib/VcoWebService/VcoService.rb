
$:.push(File.dirname(__FILE__))

require "handsoap"
require "VcoTypes"

class VcoService < Handsoap::Service
			
	Handsoap.http_driver = :HTTPClient
		
	def initialize(ep)
		super
		setNameSpace('http://webservice.vso.dunes.ch')
	end
	
	def echoWorkflow(wfMsg)
		response = invoke("n1:echoWorkflow") do |message|
			message.add "n1:workflowMessage" do |i|
				marshalObj(i, wfMsg)
			end
		end
		return(parse_response(response, 'echoWorkflowResponse')['echoWorkflowReturn'])
	end
	
	def executeWorkflow(wfId, username, password, inputs)
		response = invoke("n1:executeWorkflow") do |message|
			message.add "n1:workflowId", wfId
			message.add "n1:username", username
			message.add "n1:password", password
			inputs.each do |wfi|
				message.add "n1:workflowInputs" do |i|
					i.add "n1:name",	wfi.name
					i.add "n1:type",	wfi.type
					i.add "n1:value",	wfi.value
					# marshalObj(i, wfi)
				end
			end
		end
		return(parse_response(response, 'executeWorkflowResponse')['executeWorkflowReturn'])
	end
	
	def find(type, query, username, password)
		response = invoke("n1:find") do |message|
			message.add "n1:type", type
			message.add "n1:query", query
			message.add "n1:username", username
			message.add "n1:password", password
		end
		return(parse_response(response, 'findResponse')['findReturn'])
	end
	
	def findRelation(parentType, parentId, relationName, username, password)
		response = invoke("n1:findRelation") do |message|
			message.add "n1:parentType", parentType
			message.add "n1:parentId", parentId
			message.add "n1:relationName", relationName
			message.add "n1:username", username
			message.add "n1:password", password
		end
		return(parse_response(response, 'findRelationResponse')['findRelationReturn'])
	end
	
	def getWorkflowForId(workflowId, username, password)
		response = invoke("n1:getWorkflowForId") do |message|
			message.add "n1:workflowId", workflowId
			message.add "n1:username", username
			message.add "n1:password", password
		end
		return(parse_response(response, 'getWorkflowForIdResponse')['getWorkflowForIdReturn'])
	end
	
	def getAllWorkflows(username, password)
		response = invoke("n1:getAllWorkflows") do |message|
			message.add "n1:username", username
			message.add "n1:password", password
		end
		return(parse_response(response, 'getAllWorkflowsResponse')['getAllWorkflowsReturn'])
	end
	
	def getWorkflowTokenForId(workflowTokenId, username, password)
		response = invoke("n1:getWorkflowTokenForId") do |message|
			message.add "n1:workflowTokenId", workflowTokenId
			message.add "n1:username", username
			message.add "n1:password", password
		end
		return(parse_response(response, 'getWorkflowTokenForIdResponse')['getWorkflowTokenForIdReturn'])
	end
	
	def getWorkflowTokenStatus(workflowTokenIds, username, password)
		workflowTokenIds = [ workflowTokenIds ] unless workflowTokenIds.kind_of?(Array)
		response = invoke("n1:getWorkflowTokenStatus") do |message|
			workflowTokenIds.each do |wfid|
				message.add "n1:workflowTokenIds", wfid
			end
			message.add "n1:username", username
			message.add "n1:password", password
		end
		return(parse_response(response, 'getWorkflowTokenStatusResponse')['getWorkflowTokenStatusReturn'])
	end
	
	def getWorkflowsWithName(workflowName, username, password)
		response = invoke("n1:getWorkflowsWithName") do |message|
			message.add "n1:workflowName", workflowName
			message.add "n1:username", username
			message.add "n1:password", password
		end
		return(parse_response(response, 'getWorkflowsWithNameResponse')['getWorkflowsWithNameReturn'])
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
        elsif obj.kind_of? VcoHash
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
		# puts
		# puts "***** #{rType}"
		# dumpObj(ur)
		# puts
		return(ur)
	end
	
	def unmarshal_response(node)
		return(node.text) if node.text?
		
		if (c = node.child) && c.text?
			return String.new(c.text)
		end
		
		obj = VcoHash.new
		
		node.children.each do |c|
			if (v = obj[c.name])
				v = obj[c.name] = VcoArray.new { |a| a << v } unless v.kind_of?(Array)
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
