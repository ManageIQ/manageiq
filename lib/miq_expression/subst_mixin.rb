module MiqExpression::SubstMixin
  include ActiveSupport::Concern
  def exp_build_table_or_nil(exp)
    return nil if exp == {"???" => "???"}
    exp_build_table(exp)
  end

  # Build an array of expression symbols by recursively traversing the MiqExpression object
  #   and inserting sequential tokens for each expression part
  def exp_build_table(exp, quick_search = false)
    exp_table = []
    if exp["and"]
      exp_table.push("(")
      exp["and"].each do |e|
        exp_table += exp_build_table(e, quick_search)
        exp_table.push("AND") unless e == exp["and"].last
      end
      exp_table.push(")")
    elsif exp["or"]
      exp_table.push("(")
      exp["or"].each do |e|
        exp_table += exp_build_table(e, quick_search)
        exp_table.push("OR") unless e == exp["or"].last
      end
      exp_table.push(")")
    elsif exp["not"]
      @exp_token ||= 0
      @exp_token += 1
      exp[:token] = @exp_token
      exp_table.push(quick_search ? "NOT" : ["NOT", @exp_token])             # No token if building quick search exp
      exp_table.push("(") unless %w(and or).include?(exp["not"].keys.first)  # No parens if and/or under me
      exp_table += exp_build_table(exp["not"], quick_search)
      exp_table.push(")") unless %w(and or).include?(exp["not"].keys.first)  # No parens if and/or under me
    else
      @exp_token ||= 0
      @exp_token += 1
      exp[:token] = @exp_token
      if exp["???"]                                   # Found a new expression part
        exp_table.push(["???", @exp_token])
        exp_context[@expkey][:exp_token] = @exp_token # Save the token value for the view
        exp_context[:edit_exp] = copy_hash(exp)       # Save the exp part for the view
        exp_context[@expkey].update_from_exp_tree(exp_context[:edit_exp]) # Set the fields for a new exp part
      elsif quick_search # Separate out the user input fields if doing a quick search
        human_exp = MiqExpression.to_human(exp)
        if human_exp.include?("<user input>")
          exp_table.push(human_exp.split("<user input>").join(""))
          exp_table.push([:user_input, @exp_token])
        else
          exp_table.push(human_exp)
        end
      else # Not quick search, add token to the expression
        exp_table.push([MiqExpression.to_human(exp), @exp_token])
      end
    end
    exp_table
  end

  # Go thru an expression and replace the quick search tokens
  def exp_replace_qs_tokens(exp, tokens)
    key = exp.keys.first
    if %w(and or).include?(key)
      exp[key].each { |e| exp_replace_qs_tokens(e, tokens) }
    elsif key == "not"
      exp_replace_qs_tokens(exp[key], tokens)
    elsif exp.key?(:token) && exp[key].key?("value")
      token = exp[:token]
      if tokens[token]                # Only atoms included in tokens will have user input
        value = tokens[token][:value] # Get the user typed value
        if tokens[token][:value_type] == :bytes
          value += ".#{tokens[token][:suffix] || "bytes"}" # For :bytes type, add in the suffix
        end
        exp[key]["value"] = value # Replace the exp value with the proper qs value
      end
      exp.delete(:token)
    end
  end

  # Find an expression atom based on the token
  def exp_find_by_token(exp, token, parent_is_not = false)
    if exp.kind_of?(Array)                             # Is this and AND or OR
      result = nil
      exp.find do |e|
        result = exp_find_by_token(e, token) # Look for token
      end
      result
    elsif exp[:token] && exp[:token] == token       # This is the token exp
      @parent_is_not = true if parent_is_not        # Remember that token exp's parent is a NOT
      exp # return it
    elsif exp["not"]
      exp_find_by_token(exp["not"], token, true) # Look for token under NOT (indicate we are a NOT)
    elsif exp["and"]
      exp_find_by_token(exp["and"], token) # Look for token under AND
    elsif exp["or"]
      exp_find_by_token(exp["or"], token) # Look for token under OR
    end
  end

  # Create a hash to store quick search information by token
  # and add in other quick search exp atom information.
  def create_tokens(exp_table, orig_exp)
    exp_table.select { |e| e.kind_of?(Array) }.each_with_object({}) do |e, acc|
      token      = e.last
      acc[token] = {:value => nil}
      exp        = exp_find_by_token(orig_exp, token)
      first_exp  = exp[exp.keys.first]

      if first_exp.key?("field") # Base token settings on exp type
        field = exp[exp.keys.first]["field"]
        acc[token][:field]      = field
        acc[token][:value_type] = MiqExpression.get_col_info(field)[:format_sub_type]
      elsif first_exp.key?("tag")
        acc[token][:tag]   = first_exp["tag"]
      elsif first_exp.key?("count")
        acc[token][:count] = first_exp["count"]
      end
    end
  end

  def exp_context
    @edit
  end
end
