class PoToJson
  # return just the JSON, instead of `var locales = locales || {}; locales['en'] = json`
  def generate_for_jed(language, overwrite = {})
    @options = parse_options(overwrite.merge(:language => language))
    @parsed ||= inject_meta(parse_document)

    build_json_for(build_jed_for(@parsed))
  end
end
