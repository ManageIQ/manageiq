require_relative 'rhconsulting_illegal_chars'
require_relative 'rhconsulting_options'

class ServiceCatalogsImportExport

  def import(filedir)
    raise "Must supply filedir" if filedir.blank?
    Dir.foreach(filedir) do |filename|
      next if filename == '.' or filename == '..'
      catalogs = YAML.load_file("#{filedir}/#{filename}")
      catalogs.each {|c|
        data = []
        data << c.first[1].delete_if { |key,value| key == 'template' }
        ServiceTemplateCatalog.transaction do
          import_service_template_catalogs(data)
        end
      }
      templates = YAML.load_file("#{filedir}/#{filename}")
      templates.each {|c|
        data = []
        data << c.first[1]['template']
        data.each { |template|
          ServiceTemplate.transaction do
            import_service_templates(template)
          end
        }
      }
    end
  end

  def export(filedir, options = {})
    raise "Must supply filedir" if filedir.blank?
    catalogs_hash = export_service_template_catalogs(ServiceTemplateCatalog.in_region(MiqRegion.my_region_number).order(:id).all)
    templates_hash = export_service_templates(ServiceTemplate.in_region(MiqRegion.my_region_number).order(:id).all)
    catalogs_hash.each {|catalog|
      output = {}
      catalog_name = catalog['name']
      output["#{catalog_name}"] = catalog
      output["#{catalog_name}"]['template'] = []
      templates_hash.each {|template|
        if catalog_name == template['service_template_catalog_name']
          output["#{catalog_name}"]['template'] << template
        end
      }
      data = []
      data << output
      # Replace invalid filename characters
      fname = MiqIllegalChars.replace(output["#{catalog_name}"]['name'], options)
      File.write("#{filedir}/#{fname}.yml", data.to_yaml)
    }
  end

private

  def import_service_template_catalogs(catalogs)
    catalogs.each do |c|
      puts "Service Catalog: [#{c['name']}]"
      catalog = ServiceTemplateCatalog.in_region(MiqRegion.my_region_number).find_or_create_by(name: c['name'])
      catalog.update_attributes!(c)
    end
  end

  def import_service_templates(templates)
    templates.sort_by { |t| t['service_type'] == 'composite' ? 1 : 0 }.each do |t|
      puts "Catalog Item: [#{t['name']}]"
      template = ServiceTemplate.in_region(MiqRegion.my_region_number).find_or_create_by(name: t['name'])
      template.update_attributes!(t.slice(
        'description', 'type', 'display', 'service_type',
        'prov_type', 'provision_cost', 'long_description'))

      unless t['service_template_catalog_name'].blank?
        template.service_template_catalog = ServiceTemplateCatalog.in_region(MiqRegion.my_region_number).find_by_name(
          t['service_template_catalog_name'])
        raise "Unable to locate catalog: [#{t['service_template_catalog_name']}]" unless template.service_template_catalog
      end
      template.save!

      import_resource_actions(t['resource_actions'], template)
      import_service_resources(t['service_resources'] || [], template)
      import_custom_buttons(t['custom_buttons'], template, template)
      import_custom_button_sets(t['custom_button_sets'], template)

      import_service_template_options(t['options'], template)
      template.save!
    end
  end

  def import_service_template_options(options, template)
    template.reload
    unless options[:button_order].blank?
      custom_buttons = template.custom_buttons + template.custom_button_sets.collect do |set|
        set.reload
        set.custom_buttons
      end.flatten
      options[:button_order] = options[:button_order].collect do |name|
        values = name.split('-')
        type = values.shift
        name = values.join('-')
        case type
        when 'cb'
          custom_button = custom_buttons.find { |x| x.name == name }
          raise "Unable to locate button: [#{name}]" unless custom_button
          id = custom_button.id
        when 'cbg'
          custom_button_set = template.custom_button_sets.find_by_name(name)
          raise "Unable to locate button group: [#{name}]" unless custom_button_set
          id = custom_button_set.id
        end
        "#{type}-#{id}"
      end
    end
    template.options = options
  end

  def import_resource_actions(resource_actions, template)
    resource_actions.each do |ra|
      resource_action = template.resource_actions.find_by_action(ra['action'])
      resource_action = template.resource_actions.new unless resource_action

      dialog_label = ra.delete('dialog_label')
      unless dialog_label.blank?
        dialog = Dialog.in_region(MiqRegion.my_region_number).find_by_label(dialog_label)
        raise "Unable to locate dialog: [#{dialog_label}]" unless dialog
        ra['dialog_id'] = dialog.id
      end

      resource_action.update_attributes!(ra)
    end
  end

  def import_service_resources(service_resources, template)
    service_resources.each do |sr|
      resource_name = sr.delete('resource_name')
      resource_guid = sr.delete('resource_guid')
      child_resource = ServiceTemplate.in_region(MiqRegion.my_region_number).find_by_name_and_guid(
        resource_name, resource_guid)
      child_resource = ServiceTemplate.in_region(MiqRegion.my_region_number).find_by_name(
        resource_name) unless child_resource
      raise "Failed to locate child catalog item: [#{resource_name}]" unless child_resource

      service_resource = template.service_resources.find_by_resource_id(child_resource.id)
      service_resource = template.service_resources.new unless service_resource

      service_resource.resource = child_resource
      service_resource.update_attributes!(sr)
    end
  end

  def import_custom_buttons(custom_buttons, template, parent)
    custom_buttons.each do |cb|
      puts "Button: [#{cb['name']}]"
      custom_button = parent.custom_buttons.find { |x| x.name == cb['name'] }
      custom_button = CustomButton.new(:applies_to => template) unless custom_button

      custom_button.update_attributes!(cb) 
      parent.add_member(custom_button) if parent.respond_to?(:add_member)
    end
  end

  def import_custom_button_sets(custom_button_sets, template)
    custom_button_sets.each do |cbs|
      puts "Button Group: [#{cbs['name'].split('|').first}]"
      custom_button_set = template.custom_button_sets.find_by_name(cbs['name'])
      custom_button_set = template.custom_button_sets.new unless custom_button_set

      custom_buttons = cbs.delete('custom_buttons')
      set_data = cbs.delete('set_data')
      custom_button_set.update_attributes!(cbs)

      import_custom_buttons(custom_buttons, template, custom_button_set)

      custom_button_set.reload
      import_custom_button_set_set_data(set_data, template, custom_button_set)
      custom_button_set.save!
    end
  end

  def import_custom_button_set_set_data(set_data, template, custom_button_set)
    set_data[:button_order] = set_data[:button_order].collect do |name|
      child_button = custom_button_set.custom_buttons.find { |x| x.name == name }
      child_button.id if child_button
    end.compact
    set_data[:applies_to_class] = 'ServiceTemplate' 
    set_data[:applies_to_id] = template.id
    custom_button_set.set_data = set_data
  end

  def export_service_template_catalogs(catalogs)
    catalogs.collect { |catalog| catalog.attributes.slice('name', 'description') } 
  end

  def export_service_template_options(options)
    if options[:button_order]
      options[:button_order] = options[:button_order].collect do |order|
        type, id = order.split('-')
        case type
        when 'cb'
          record = CustomButton.find_by_id(id)
        when 'cbg'
          record = CustomButtonSet.find_by_id(id)
        end
        "#{type}-#{record.name}" if record
      end.compact
    end
    options
  end

  def export_service_templates(templates)
    templates.collect do |template|
      attributes = template.attributes.slice(
        'name', 'description', 'type', 'display', 'service_type',
        'prov_type', 'provision_cost', 'long_description')
      attributes['options'] = export_service_template_options(template.options)
      attributes['service_template_catalog_name'] = template.service_template_catalog.name if template.service_template_catalog
      attributes['resource_actions'] = export_resource_actions(template.resource_actions)
      attributes['service_resources'] = export_service_resources(template.service_resources) if template.service_type == "composite"
      attributes['custom_buttons'] = export_custom_buttons(template.custom_buttons)
      attributes['custom_button_sets'] = export_custom_button_sets(template.custom_button_sets)
      attributes
    end
  end

  def export_resource_actions(resource_actions)
    resource_actions.collect do |resource_action|
      attributes = resource_action.attributes.slice(
        'action', 'ae_namespace', 'ae_class', 'ae_instance', 'ae_message', 'ae_attributes')
      attributes['dialog_label'] = resource_action.dialog.label if resource_action.dialog
      attributes
    end 
  end

  def export_service_resources(service_resources)
    service_resources.collect do |service_resource|
      next unless service_resource.resource
      attributes = service_resource.attributes.slice(
        'group_idx', 'scaling_min', 'scaling_max', 'start_action', 'start_delay',
        'stop_action', 'stop_delay', 'name', 'provision_index')
      attributes['resource_name'] = service_resource.resource.name
      attributes['resource_guid'] = service_resource.resource.guid
      attributes
    end.compact 
  end

  def export_custom_buttons(custom_buttons)
    custom_buttons.collect do |custom_button|
      custom_button.attributes.slice(
        'description', 'applies_to_exp', 'options', 'userid',
        'wait_for_complete', 'name', 'visibility')
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

end

namespace :rhconsulting do
  namespace :service_catalogs do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake rhconsulting:service_catalogs:export[/path/to/dir/with/service_catalogs]'
      puts 'Import - Usage: rake rhconsulting:service_catalogs:import[/path/to/dir/with/service_catalogs]'
    end

    desc 'Import all dialogs from a YAML file'
    task :import, [:filedir] => [:environment] do |_, arguments|
      ServiceCatalogsImportExport.new.import(arguments[:filedir])
    end

    desc 'Exports all dialogs to a YAML file'
    task :export, [:filedir] => [:environment] do |_, arguments|
      options = RhconsultingOptions.parse_options(arguments.extras)
      ServiceCatalogsImportExport.new.export(arguments[:filedir], options)
    end

  end
end

