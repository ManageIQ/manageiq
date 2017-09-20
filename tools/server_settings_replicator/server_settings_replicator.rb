class ServerSettingsReplicator
  def self.replicate(server, path_string, dry_run = false)
    path = path_string.split("/").map(&:to_sym)

    # all servers except source
    target_servers = MiqServer.where.not(:id => server.id)
    settings = construct_setting_tree(path, server.settings_for_resource.fetch_path(path).to_h)

    puts "Replicating from server id=#{server.id}, path=#{path_string} to #{target_servers.count} servers"
    puts "Settings: #{settings}"

    if dry_run
      puts "Dry run, no updates have been made"
    else
      copy_to(target_servers, settings)
    end
    puts "Done"
  end

  def self.construct_setting_tree(path, values)
    # construct the partial tree containing the target values
    path.reverse.inject(values) { |merged, element| {element => merged} }
  end

  def self.copy_to(target_servers, target_settings)
    target_servers.each do |target|
      puts " - replicating to server id=#{target.id}..."
      target.add_settings_for_resource(target_settings)
    end
  end
end
