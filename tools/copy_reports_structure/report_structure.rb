class ReportStructure

  def self.duplicate_for_group(source_group_name, destination_group_name, dry_run = false)
    puts "Copying report structure from group '#{source_group_name}' to group ' #{destination_group_name}' ..."
    destination_group = find_group(destination_group_name)
    destination_group.update!(:settings => find_group(source_group_name).settings) unless dry_run
    puts "Reports structure was successfully copied from '#{source_group_name}' to '#{destination_group_name}'"
  rescue StandardError => e
    $stderr.puts "Copying failed: #{e.message}"
  end

  def self.duplicate_for_role(source_group_name, destination_role_name, dry_run = false)
    puts "Copying report structure from group '#{source_group_name}' to role ' #{destination_role_name}' ..."
    source_group = find_group(source_group_name)
    find_role(destination_role_name).miq_groups.each do |destination_group|
      begin
        destination_group.update!(:settings => source_group.settings) unless dry_run
        puts "  Reports structure was successfully copied from '#{source_group_name}' to '#{destination_group.description}'"
      rescue StandardError => e
        $stderr.puts "Copying failed: #{e.message}"
      end
    end
  end

  def self.reset_for_group(group_name, dry_run = false)
    puts "Removing custom report structure for group '#{group_name}'..."
    group = find_group(group_name)
    begin
      group.update!(:settings => nil) unless dry_run
      puts "Successfully removed custom report structure for group '#{group_name}'"
    rescue StandardError => e
      $stderr.puts "Removing failed: #{e.message}"
    end
  end

  def self.reset_for_role(role_name, dry_run = false)
    puts "Removing custom report structure for role '#{role_name}'..."
    find_role(role_name).miq_groups.each do |group|
      begin
        group.update!(:settings => nil) unless dry_run
        puts "Successfully removed custom report structure for group '#{group.description}'"
      rescue  StandardError => e
        $stderr.puts "Removing failed: #{e.message}"
      end
    end
  end

  def self.find_group(group_name)
    group = MiqGroup.where(:description => group_name).first
    abort("MiqGroup  '#{group_name}' not found") if group.nil?
    group
  end

  def self.find_role(role_name)
    role = MiqUserRole.where(:name => role_name).first
    abort("MiqUserRole  '#{role_name}' not found") if role.nil?
    role
  end
end

