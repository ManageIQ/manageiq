
$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'MiqVcoClientBase'

begin
	work_flow_name	= "Power off VM and wait"
	target_vm		= 'Fedora7'

	vco = MiqVcoClientBase.new(SOURCE_HOST, USERNAME, PASSWORD)
	
	wf = vco.getWorkflowsWithName(work_flow_name)
	vms = vco.findByFilter("VC:VirtualMachine", 'name' => target_vm)[0]
	
	inputs = VcoArray.new('ArrayOfWorkflowTokenAttribute') do |ia|
		ia << VcoHash.new('WorkflowTokenAttribute') do |i|
			i.name	= 'vm'
			i.type	= vms.type
			i.value	= vms.dunesUri
		end
	end
	
	rv = vco.executeWorkflow(wf.id, inputs)
	vco.dumpObj(rv)
	puts
	puts "***** Work flow state: #{rv.globalState}"
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
