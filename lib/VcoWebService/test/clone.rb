
$:.push("#{File.dirname(__FILE__)}/..")

require_relative '../../bundler_setup'
require 'MiqVcoClientBase'

begin
	work_flow_name	= "Clone VM (No customization at all)"
	target_vm		= 'Fedora7'
	to_host			= TARGET_HOST
	
	vco = MiqVcoClientBase.new(SOURCE_HOST, USERNAME, PASSWORD)
	
	# awf = vco.getAllWorkflows
	# awf.each { |wf| puts wf.name }
	# exit
	
	wf = vco.getWorkflowsWithName(work_flow_name)
	vco.dumpObj(wf)
	
	vms = vco.findByFilter("VC:VirtualMachine", 'name' => target_vm)[0]
	vco.dumpObj(vms)
	
	fo = vco.findByFilter("VC:VmFolder", 'name' => "vm")[0]
	vco.dumpObj(fo)
	
	inputs = VcoArray.new('ArrayOfWorkflowTokenAttribute') do |ia|
		ia << VcoHash.new('WorkflowTokenAttribute') do |i|
			i.name	= 'vm'
			i.type	= vms.type
			i.value	= vms.dunesUri
		end
		ia << VcoHash.new('WorkflowTokenAttribute') do |i|
			i.name	= 'vmFolder'
			i.type	= fo.type
			i.value	= fo.dunesUri
		end
		ia << VcoHash.new('WorkflowTokenAttribute') do |i|
			i.name	= 'name'
			i.type	= 'string'
			i.value	= "#{target_vm}-rpo-clone"
		end
		ia << VcoHash.new('WorkflowTokenAttribute') do |i|
			i.name	= 'powerOn'
			i.type	= 'boolean'
			i.value	= "false"
		end
		ia << VcoHash.new('WorkflowTokenAttribute') do |i|
			i.name	= 'template'
			i.type	= 'boolean'
			i.value	= "false"
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
