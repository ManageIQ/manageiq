class AeLoader
  attr_accessor :handle

  def initialize(handle=$evm)
    # use the provides AeWorkspace or create a new one
    @handle = handle.presence || get_evm
    # this accessor method is needed (I know it is not pretty)
    def @handle.workspace
      @workspace
    end
    @handle.workspace.instance_variable_get(:@dom_search).ae_user = User.where(userid: 'admin').first
  end

  # Create a new empty AeWorkspace (essentially $evm)
  def get_evm
    workspace = MiqAeEngine::MiqAeWorkspaceRuntime.new
    workspace.ae_user = User.where(:userid => 'admin').first
    MiqAeMethodService::MiqAeService.new(workspace)
  end

  # Find a MiqAeMethod object with a given path
  def aem_from_path(path)
	# remove spaces etc
	path.gsub!(/ /, '')
    puts "Resolving Method: #{path}"
    parts = path.split('/').compact
    name = parts.pop
    klass = parts.pop
    ns = parts.join('/')

    methods = MiqAeMethod.where(name: name)
    puts "Method not found!" if methods.length == 0
    return methods.first if methods.length <= 1

    puts "Found #{methods.length} MiqAeMethods"
    methods = methods.select{|m| m.ae_class.name == klass && m.ae_class.ae_namespace.fqname.include?(ns) }.first
  end

 
 # load only embedded methods into the current context
  # Accepts a MiqAeMthod object or a path
  def include_embedded_methods(aem)
    aem = aem_from_path(aem).presence || aem if aem.kind_of?(String)
    return (puts "Unable to find MiqAeMethod for #{aem}").to_s unless aem.kind_of?(MiqAeMethod)

    # Use ManageIQs embedded method resolution method (:bodies_and_line_numbers) to find embedded code
    puts "Include Embedded Methods for: #{aem.name}"
    data =  MiqAeEngine::MiqAeMethod.send(:bodies_and_line_numbers, @handle, aem)
    # remove last element, because it is aem's method body
    data[0].slice(0...-1).join("\n") 
  end

  # load the method AND embedded methods into the current context
  def include_method(aem)
    aem = aem_from_path(aem).presence || aem if aem.kind_of?(String)

    embedded = include_embedded_methods(aem)
    # always return a string
    return (puts "Unable to find MiqAeMethod for #{aem}").to_s unless aem.kind_of?(MiqAeMethod)

    puts "Include Method: #{aem.name}"
    embedded.to_s + "\n" + aem.data.to_s
  end
  # export methods to file
  def export_method(aem)
	methods = include_method(aem)
	method_name = aem_from_path(aem).name
	File.open("#{method_name}.rb", 'w') { |f| f.puts methods}	
  end
end

puts "3-AAAAAAAAAAAAAAAA"
$ael = AeLoader.new
$evm = $ael.get_evm
#eval(ae.include_embedded_methods('StdLib/Automate/Validation/lib_validation'))
#eval(ae.include_method('StdLib/Automate/Validation/lib_validation'))
#eval(ae.include_method('StdLib/Automate/Validation/invalid'))