class Dictionary
  FIXTURE_FILE = File.join(Rails.root, "db/fixtures", "#{self.to_s.pluralize.underscore}.csv")

  def self.dict
    @dict ||= load
  end

  def self.load
    skip_header = true
    File.read(FIXTURE_FILE).lines.each_with_object({}) do |line, dictionary|
      if skip_header
        skip_header = false
        next
      end
      next if line.blank? || line.starts_with?("#")

      typ, name, text, locale = line.chomp.split(',')
      dictionary.store_path(locale.strip, "dictionary", typ.strip, name.strip, text.strip)
    end
  end

  def self.gettext(text, opts = {})
    opts[:locale]   ||= "en"
    opts[:type]     ||= :column

    t1, t2  = text.split("__")
    result  = dict.fetch_path(opts[:locale], "dictionary", opts[:type].to_s, t1.split(".").last)
    result += " (#{t2.titleize})" if result && t2

    return result if result
    return text unless opts[:notfound]

    col = text.split(".").last
    col = col[2..-1] if col.starts_with?("v_")
    col.send(opts[:notfound]) if opts[:notfound].to_sym == :titleize
  end
end
