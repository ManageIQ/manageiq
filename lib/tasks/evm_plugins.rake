namespace :evm do
  namespace :plugins do
    desc "List the available plugins in the specified format ('human' or 'json')"
    task :list, :format do |_, args|
      format = args.fetch(:format, "human")

      require "vmdb/plugins"
      details = Vmdb::Plugins.details

      case format
      when "json"
        puts JSON.pretty_generate(details.values)
      when "human"
        details.each_value do |detail|
          puts "#{detail[:name]}:"
          puts detail
            .except(:name)
            .map { |k, v| "  #{k}: #{v}" }
        end
      else
        raise "Invalid format #{format.inspect}"
      end
    end
  end
end
