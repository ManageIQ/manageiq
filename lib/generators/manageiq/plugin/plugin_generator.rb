module ManageIQ
  class PluginGenerator < Rails::Generators::NamedBase
    source_root File.expand_path('templates', __dir__)
    source_paths << source_root

    remove_class_option :skip_namespace

    class_option :path, :type => :string, :default => 'plugins',
                 :desc => "Create plugin at given path"

    def self.namespace
      # Thor has its own version of snake_case, which doesn't account for acronyms
      name.underscore.tr("/", ":").sub(/_generator$/, "")
    end

    def create_plugin_dir
      base_path = File.expand_path(options[:path], destination_root)
      self.destination_root = File.expand_path(plugin_name, base_path)
      empty_directory "."
      git :init => destination_root unless Dir.exist?(File.join(destination_root, ".git"))
      FileUtils.cd(destination_root)
    end

    def create_plugin_files
      template "%plugin_name%.gemspec"
      template ".codeclimate.yml"
      template ".gitignore"
      template ".rspec"
      template ".rspec_ci"
      template ".rubocop.yml"
      template ".rubocop_cc.yml"
      template ".rubocop_local.yml", :skip => true
      template ".travis.yml"
      template ".yamllint"
      template "Gemfile"
      template "LICENSE.txt"
      template "Rakefile"
      template "README.md"
      template "bin/ci/after_script"
      template "bin/rails"
      template "bin/setup"
      template "bin/update"
      chmod "bin", 0755 & ~File.umask, :verbose => false
      empty_directory_with_keep_file "bundler.d"
      template "config/settings.yml"
      template "lib/%plugin_name%.rb"
      template "lib/%plugin_path%/engine.rb"
      template "lib/%plugin_path%/version.rb"
      template "lib/tasks/README.md"
      template "lib/tasks_private/spec.rake"
      empty_directory_with_keep_file "locale"
      empty_directory "spec/factories"
      empty_directory "spec/support"
      template "spec/spec_helper.rb"
    end

    def insert_manageiq_gem
      data = <<~GEMFILE
        group :#{file_name}, :manageiq_default do
          manageiq_plugin "#{plugin_name}" # TODO: Sort alphabetically...
        end
      GEMFILE
      inject_into_file Rails.root.join('Gemfile'), "\n#{data}\n", :after => "### providers\n"
    end

    private

    INDENT = "  ".freeze

    alias plugin_path file_path

    def plugin_name
      @plugin_name ||= plugin_path.tr("/", "-")
    end

    def plugin_human_name
      @plugin_human_name ||= class_name.titleize.tr("/", " ")
    end

    def plugin_description
      @plugin_description ||= "#{file_name.titleize} plugin for #{Vmdb::Appliance.PRODUCT_NAME}."
    end

    def empty_directory_with_keep_file(destination, config = {})
      empty_directory(destination, config)
      keep_file(destination)
    end

    def keep_file(destination)
      create_file("#{destination}/.keep")
    end

    # Emits the plugin_name in a form suitable for a rake namespace
    #
    # Example:
    #   namespace <%= rake_task_namespace %> do
    #
    #   # when plugin_name == "foo"
    #   namespace :foo do
    #
    #   # when plugin_name == "foo-bar-baz"
    #   namespace 'foo:bar:baz' do
    def rake_task_namespace
      @rake_task_namespace ||=
        if plugin_name.include?("-")
          plugin_name.tr("-", ":").inspect
        else
          plugin_name.to_sym.inspect
        end
    end

    # Emits the class_name in exploded module form, indenting the content of
    #   the block appropriately.
    #
    # Example:
    #   <% exploded_class_name do %>
    #     VERSION = '0.1.0'.freeze
    #   <% end %>
    #
    #   # when the class_name is Foo::Bar::Baz
    #   module Foo
    #     module Bar
    #       module Baz
    #         VERSION = '0.1.0'.freeze
    #       end
    #     end
    #   end
    def exploded_class_name(&block)
      content = capture(&block)
      content = content[1..-2] if content.start_with?("\n") && content.end_with?("\n")

      parts = class_name.split("::")
      max = parts.size - 1

      output_buffer << parts.map.with_index { |m, i| "module #{m}\n".indent(i, INDENT) }.join
      output_buffer << content.indent(max, INDENT) << "\n"
      output_buffer << max.downto(0).map { |i| "end\n".indent(i, INDENT) }.join
      output_buffer.chomp!
    end

    #
    # capture and with_output_buffer copied from ActionView::Helpers::CaptureHelper.
    #   This version of these methods avoid the HTML escaping done at various stages.
    #

    def capture(*args)
      value = nil
      with_output_buffer { value = yield(*args) }.presence || value
    end

    def with_output_buffer(buf = nil) #:nodoc:
      unless buf
        buf = ""
        if output_buffer && output_buffer.respond_to?(:encoding)
          buf.force_encoding(output_buffer.encoding)
        end
      end
      self.output_buffer, old_buffer = buf, output_buffer
      yield
      output_buffer
    ensure
      self.output_buffer = old_buffer
    end
  end
end
