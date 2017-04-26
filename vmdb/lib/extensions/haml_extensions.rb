#
# Automatic gettext translation in HAML files
# With this trick, there is no need to call the _() method on static text in HAML
#
# Inspired by:
# http://www.nanoant.com/programming/haml-gettext-automagic-translation
# https://github.com/potager/haml-magic-translations
#
module Haml
  class Parser
    # Inject _() call on texts between tags
    def parse_tag(line)
      tag_name, attributes, attributes_hashes, object_ref, nuke_outer_whitespace,
        nuke_inner_whitespace, action, value, last_line = super(line)
      value = "\#{_('#{value.dump}')" unless action || value.empty?

      [
        tag_name,
        attributes,
        attributes_hashes,
        object_ref,
        nuke_outer_whitespace,
        nuke_inner_whitespace,
        action,
        value,
        last_line
      ]
    end

    # Same as parse_tag with plaintext
    def plain(text)
      script("\#{_('#{text.dump}')")
    end
  end
end
