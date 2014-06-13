
$:.push(File.dirname(__FILE__))

require "handsoap"
require "ServiceNowTypes"

class SnSctaskService < Handsoap::Service

	Handsoap.http_driver = :HTTPClient

	DEFAULT_NAMESPACE = 'http://www.service-now.com/sc_task'

	def initialize(ep)
		super
		setNameSpace(DEFAULT_NAMESPACE)
	end
	
	def getRecords(params)
		response = invoke("n1:getRecords") do |message|
			params.each do |k, v|
				message.add "n1:#{k}", v
			end
			# addParam(message, params, "active")
			# addParam(message, params, "activity_due")
			# addParam(message, params, "approval")
			# addParam(message, params, "approval_history")
			# addParam(message, params, "approval_set")
			# addParam(message, params, "assigned_to")
			# addParam(message, params, "assignment_group")
			# addParam(message, params, "business_duration")
			# addParam(message, params, "calendar_duration")
			# addParam(message, params, "calendar_stc")
			# addParam(message, params, "close_notes")
			# addParam(message, params, "closed_at")
			# addParam(message, params, "closed_by")
			# addParam(message, params, "cmdb_ci")
			# addParam(message, params, "comments")
			# addParam(message, params, "company")
			# addParam(message, params, "contact_type")
			# addParam(message, params, "correlation_display")
			# addParam(message, params, "correlation_id")
			# addParam(message, params, "delivery_plan")
			# addParam(message, params, "delivery_task")
			# addParam(message, params, "description")
			# addParam(message, params, "due_date")
			# addParam(message, params, "escalation")
			# addParam(message, params, "expected_start")
			# addParam(message, params, "follow_up")
			# addParam(message, params, "group_list")
			# addParam(message, params, "impact")
			# addParam(message, params, "knowledge")
			# addParam(message, params, "location")
			# addParam(message, params, "made_sla")
			# addParam(message, params, "number")
			# addParam(message, params, "opened_at")
			# addParam(message, params, "opened_by")
			# addParam(message, params, "order")
			# addParam(message, params, "parent")
			# addParam(message, params, "priority")
			# addParam(message, params, "request_item")
			# addParam(message, params, "short_description")
			# addParam(message, params, "sla_due")
			# addParam(message, params, "state")
			# addParam(message, params, "sys_class_name")
			# addParam(message, params, "sys_created_by")
			# addParam(message, params, "sys_created_on")
			# addParam(message, params, "sys_domain")
			# addParam(message, params, "sys_id")
			# addParam(message, params, "sys_mod_count")
			# addParam(message, params, "sys_updated_by")
			# addParam(message, params, "sys_updated_on")
			# addParam(message, params, "time_worked")
			# addParam(message, params, "upon_approval")
			# addParam(message, params, "upon_reject")
			# addParam(message, params, "urgency")
			# addParam(message, params, "user_input")
			# addParam(message, params, "watch_list")
			# addParam(message, params, "work_end")
			# addParam(message, params, "work_notes")
			# addParam(message, params, "work_start")
			# addParam(message, params, "__use_view")
			# addParam(message, params, "__encoded_query")
			# addParam(message, params, "__limit")
			# addParam(message, params, "__first_row")
			# addParam(message, params, "__last_row")
			# addParam(message, params, "__order_by")
			# addParam(message, params, "__order_by_desc")
			# addParam(message, params, "__exclude_columns")
		end
		rv = parse_response(response, 'getRecordsResponse')['getRecordsResult']
		return rv if rv.kind_of?(Array)
		return [] if rv.nil?
		return [ rv ]
	end
	
	def update(params)
		response = invoke("n1:update") do |message|
			params.each do |k, v|
				message.add "n1:#{k}", v
			end
		end
		rv = parse_response(response, 'updateResponse')
		return rv
	end

	private
	
	def addParam(msg, params, pname)
		unless (p = params[pname]).nil?
			msg.add "n1:#{pname}", p
		end
	end

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
