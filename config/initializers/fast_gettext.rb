old_debug, $DEBUG = $DEBUG, nil
begin
  # The `gettext` gem unreasonably assumes that anyone with $DEBUG
  # enabled must want a flood of racc/yydebug output. As we're actually
  # trying to debug something other than their parser, we need to
  # temporarily force it off while we load stuff.
  Vmdb::FastGettextHelper.register_locales
ensure
  $DEBUG = old_debug
end
