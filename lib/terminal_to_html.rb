class TerminalToHtml
  def self.render(raw)
    wrap_html_container(raw_render(raw))
  end

  def self.raw_render(raw)
    require "terminal"
    Terminal.render(raw)
  end

  def self.wrap_html_container(rendered)
    stylesheet = File.read(File.join(Bundler.load.specs["terminal"].first.full_gem_path, "/app/assets/stylesheets/terminal.css"))
    <<~EOHTML
      <div>
      <style scoped>
      #{stylesheet.chomp}
      </style>
      <div class='term-container'>
      #{rendered}
      </div>
      </div>
    EOHTML
  end
end
