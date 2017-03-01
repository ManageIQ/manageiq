require_relative 'rhconsulting_illegal_chars'
require_relative 'rhconsulting_options'

class ButtonsImportExport

  def import(filename)
    raise "Must supply filename or directory" if filename.blank?
    if File.file?(filename)
      import_file(filename)
    elsif File.directory?(filename)
      Dir.glob("#{filename}/*.yaml") do |fname|
        import_file(fname)
      end
    else
      raise "Argument is not a filename or directory"
    end
  end

  def export(filename, options = {})
    raise "Must supply filename or directory" if filename.blank?
    begin
      file_type = File.ftype(filename)
    rescue
      # If we get an error back assume it is a filename that does not exist
      file_type = 'file'
    end

    custom_buttons_sets_hash = export_custom_button_sets(CustomButtonSet.in_region(MiqRegion.my_region_number).order(:id).all)
    custom_button_find = CustomButton.in_region(MiqRegion.my_region_number).order(:id).all
    bf_array = []
    custom_button_find.each do |bf|
      if bf['applies_to_class'] != "ServiceTemplate"
        #puts bf.inspect
        bf_array << bf
      end
    end
    custom_buttons_hash = export_custom_buttons(bf_array)

#      custom_buttons_hash = export_custom_buttons(CustomButton.in_region(MiqRegion.my_region_number))
#puts custom_buttons_sets_hash.inspect
#puts custom_buttons_hash.inspect
#File.write(filename, {:custom_buttons_sets => custom_buttons_sets_hash, :custom_buttons => custom_buttons_hash}.to_yaml)
#puts "Filename: #{filename}"
    if file_type == 'file'
      File.write(filename, {:custom_buttons_sets => custom_buttons_sets_hash}.to_yaml)
    elsif file_type == 'directory'
      custom_buttons_sets_hash.each do |cbs|
        # Replace characters in the name that are not allowed in filenames
        name = MiqIllegalChars.replace("#{cbs["name"]}", options)
        fname = "#{filename}/#{name}.yaml"
        File.write(fname, {:custom_buttons_sets => [cbs]}.to_yaml)
      end
    else
      raise "Argument is not a filename or directory"
    end
  end

  private

  def import_file(filename)
    contents = YAML.load_file(filename)
    CustomButton.transaction do
      import_custom_button_sets(contents[:custom_buttons_sets])
    end
  end

  def import_resource_actions(custom_button, resource_actions, cbs)
    #count = 0
    #cbs.each do | cb_entry |
    #   puts "CBS Entry"
    #   puts cb_entry.class
    #   puts cb_entry.inspect
    #   
    #   if cb_entry['name'] == name
    #      puts "Updating CB Entry"
    #      cb_entry['resource_actions'] = resource_actions
    #      cbs[count]=cb_entry
    #      puts cbs.inspect
    #      puts cb_entry['resource_actions']
    #   end
    #   count += 1
    #end
    resource_action = ResourceAction.new
    all_ra = ResourceAction.in_region(MiqRegion.my_region_number)
    all_ra.each do |find_action|
      #  puts "checking ra: #{find_action['id']} if it has resource_id of #{find_action['resource_id']}"
      if find_action['resource_id'] == custom_button.id
        #    puts "FOUND: #{find_action.inspect}"
        resource_action = find_action
        resource_action.reload
      end
    end

    #puts "ResourceActions PRE: #{resource_action.inspect}"
    ra = {}
    ra['action'] = resource_actions['action']
    ra['resource_id'] = custom_button.id
    ra['resource_type'] = "CustomButton"
    ra['ae_namespace'] = resource_actions['ae_namespace']
    ra['ae_class'] = resource_actions['ae_class']
    ra['ae_instance'] = resource_actions['ae_instance']
    ra['ae_message'] = resource_actions['ae_message']
    ra['ae_attributes'] = resource_actions['ae_attributes']
    dialog_label = resource_actions['dialog_label']
    #puts "dialog_label: #{dialog_label.inspect}"
    unless dialog_label.nil?
      dialog = Dialog.in_region(MiqRegion.my_region_number).find_by_label(dialog_label)
      #puts "dialog: #{dialog.inspect}"
      raise "Unable to locate dialog: [#{dialog_label}]" unless dialog
      ra['dialog_id'] = dialog.id
    end
    resource_action.update_attributes!(ra)
    resource_action.reload
    resource_action.save!
    #puts "ResourceActions POST: #{resource_action.inspect}"
  end

  def import_custom_buttons(custom_buttons, cbs, parent)
    #puts "ParentID: #{parent['id'].inspect}"
    count = 0
    custom_buttons.each do |cb|
      if CustomButton.in_region(MiqRegion.my_region_number).find_by(:description => cb['name']).nil?
        puts "\t\tAdding Button: #{cb['name']}"
        resource_actions = cb['resource_actions']
        #puts cb['resource_actions'].inspect
        cb.delete('resource_actions')
        # The same name can be used in different Object Types so we need to make
        # sure to check for that.
        custom_button = CustomButton.in_region(MiqRegion.my_region_number).
          find_by_name_and_applies_to_class(cb['name'], cb['applies_to_class'])
        #      custom_button = cb.custom_buttons.find { |x| x.name == cb['name'] }
        custom_button = CustomButton.new(:applies_to_id => "#{parent['id']}") unless custom_button
        #puts "CustomButton search: #{custom_button.inspect}"
        #cb['resource_actions'] = ra
        #puts "After Import"
        #puts cb.inspect
        #puts "After Import"
        #  button['resource_actions'] = ra
        #puts "button: #{button.inspect}"
        if !custom_button.nil?
          #puts "Updating custom button [#{cb['name']}]"
          #puts cb.inspect
          custom_button['name'] = cb['name']
          custom_button['description'] = cb['description']
          custom_button['applies_to_class'] = cb['applies_to_class']
          custom_button['applies_to_exp'] = cb['applies_to_exp']
          custom_button['options'] = cb['options']
          custom_button['userid'] = cb['userid']
          custom_button['wait_for_complete'] = cb['wait_for_complete']
          custom_button['visibility'] = cb['visibility']
          custom_button['applies_to_id'] = cb['applies_to_id']
          #custom_button['resource_actions'] = cb['resource_actions']
          custom_button.resource_action = cb['resource_actions']
          custom_button.update_attributes!(cb) unless !custom_button.nil?
          # puts "Updated custom button [#{cb['name']}]"
          # puts custom_button.inspect
          custom_button.save!
          parent.add_member(custom_button) if parent.respond_to?(:add_member)
          custom_buttons[count] = custom_button
          count += 1
          #puts custom_buttons.inspect
          #puts resource_actions.inspect
          import_resource_actions(custom_button, resource_actions, custom_buttons)
        end
      else
        puts "Button #{cb['name']} already a part of existing Button Group"
      end
    end
  end

  def import_custom_button_sets(custom_button_sets)
    custom_button_sets.each do |cbs|
      puts "Button Class: [#{cbs['name'].split('|')[1]}]"
      puts "\tButton Group: [#{cbs['name'].split('|').first}]"

      #puts cbs.inspect
      custom_button_set = CustomButtonSet.in_region(MiqRegion.my_region_number).find_by_name(cbs['name'])
      custom_button_set = CustomButtonSet.new unless custom_button_set

      custom_buttons = cbs.delete('custom_buttons')
      set_data = cbs.delete('set_data')
      custom_button_set.update_attributes!(cbs)
      custom_button_set.reload
      import_custom_buttons(custom_buttons, cbs, custom_button_set)
      import_custom_button_set_set_data(set_data, cbs, custom_button_set)
      custom_button_set.update_attributes!(cbs)
      custom_button_set.save!
    end
  end

  def import_custom_button_set_set_data(set_data, cbs, custom_button_set)
    set_data[:button_order] = set_data[:button_order].collect do |name|
      child_button = custom_button_set.custom_buttons.find { |x| x.name == name }
      child_button.id if child_button
    end.compact
    #puts custom_button_set.inspect
    set_data[:applies_to_class] = cbs['name'].split('|').second
    #    set_data[:applies_to_id] = custom_button_set.id
    custom_button_set.set_data = set_data
  end

  def export_custom_buttons(custom_buttons)
    buttons = []
    custom_buttons.each do |b|
      button = {}
      custom_buttons.collect do |custom_button|
        button = custom_button.attributes.slice(
            'description', 'applies_to_class', 'applies_to_exp', 'options', 'userid',
            'wait_for_complete', 'name', 'visibility', 'applies_to_id')
        button['resource_actions'] = export_resource_actions(custom_button.resource_action)
        buttons << button
      end
      return buttons
    end
  end

  def export_custom_button_set_data(set_data)
    set_data.reject! { |k,v| [:applies_to_class, :applies_to_id].include?(k) }
    set_data[:button_order] = set_data[:button_order].collect do |button|
      b = CustomButton.find_by_id(button)
      b.name if b
    end.compact
    set_data
  end

  def export_custom_button_sets(custom_button_sets)
    custom_button_sets.collect do |custom_button_set|
      attributes = custom_button_set.attributes.slice(
          'name', 'description', 'set_type', 'read_only', 'mode')
      attributes['custom_buttons'] = export_custom_buttons(custom_button_set.custom_buttons)
      attributes['set_data'] = export_custom_button_set_data(custom_button_set.set_data)
      attributes
    end
  end

  def export_resource_actions(resource_actions)
    attributes = {}
    # Added a check here
    if !resource_actions.nil?
      #puts resource_actions.inspect
      attributes['action'] = resource_actions['action']
      attributes['ae_namespace'] = resource_actions['ae_namespace']
      attributes['ae_class'] = resource_actions['ae_class']
      attributes['ae_instance'] = resource_actions['ae_instance']
      attributes['ae_message'] = resource_actions['ae_message']
      attributes['ae_attributes'] = resource_actions['ae_attributes']
      #puts resource_actions.methods
      #puts resource_actions.dialog.inspect
      # puts resource_action.methods
      attributes['dialog_label'] = resource_actions.dialog.label if resource_actions.dialog
      attributes
    end
  end


end

namespace :rhconsulting do
  namespace :buttons do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake rhconsulting:buttons:export[/path/to/export]'
      puts 'Import - Usage: rake rhconsulting:buttons:import[/path/to/import]'
    end

    desc 'Import all dialogs from a YAML file'
    task :import, [:filename] => [:environment] do |_, arguments|
      ButtonsImportExport.new.import(arguments[:filename])
    end

    desc 'Exports all dialogs to a YAML file'
    task :export, [:filename] => [:environment] do |_, arguments|
      options = RhconsultingOptions.parse_options(arguments.extras)
      ButtonsImportExport.new.export(arguments[:filename], options)
    end

  end
end
