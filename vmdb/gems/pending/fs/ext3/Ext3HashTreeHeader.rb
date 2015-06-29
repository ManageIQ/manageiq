$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext3
		
	# ////////////////////////////////////////////////////////////////////////////
	# // Data definitions.

	HASH_TREE_HEADER = [
		'L',	'unused1',		# Unused.
		'C',	'hash_ver',		# Hash version.
		'C',	'length',			# Length of this structure.
		'C',	'leaf_level',	# Levels of leaves.
		'C',	'unused2',		# Unused.
	]

	class HashTreeHeader


	end
end
