module ScopedSearch::QueryLanguage::Parser

  DEFAULT_SEQUENCE_OPERATOR = :and
  
  LOGICAL_INFIX_OPERATORS  = [:and, :or]
  LOGICAL_PREFIX_OPERATORS = [:not]
  NULL_PREFIX_OPERATORS    = [:null, :notnull]
  COMPARISON_OPERATORS = [:eq, :ne, :gt, :gte, :lt, :lte, :like, :unlike]
  ALL_INFIX_OPERATORS = LOGICAL_INFIX_OPERATORS + COMPARISON_OPERATORS
  ALL_PREFIX_OPERATORS = LOGICAL_PREFIX_OPERATORS + COMPARISON_OPERATORS + NULL_PREFIX_OPERATORS
  
  def parse
    @tokens = tokenize   
    parse_expression_sequence(true).simplify
  end

  def parse_expression_sequence(initial = false)
    expressions = []
    next_token if !initial && peek_token == :lparen # skip staring :lparen    
    expressions << parse_logical_expression until peek_token.nil? || peek_token == :rparen
    next_token if !initial && peek_token == :rparen # skip final :rparen
    return ScopedSearch::QueryLanguage::AST::LogicalOperatorNode.new(DEFAULT_SEQUENCE_OPERATOR, expressions)
  end
  
  def parse_logical_expression
    lhs = case peek_token
      when nil;             nil
      when :lparen;         parse_expression_sequence
      when :not;            parse_logical_not_expression
      when :null, :notnull; parse_null_expression
      else;                 parse_comparison
    end

    if LOGICAL_INFIX_OPERATORS.include?(peek_token)
      operator = next_token
      rhs = parse_logical_expression
      ScopedSearch::QueryLanguage::AST::LogicalOperatorNode.new(operator, [lhs, rhs])
    else
      lhs
    end
  end  
  
  def parse_logical_not_expression
    next_token # = skip NOT operator
    negated_expression = case peek_token
      when :not;    parse_logical_not_expression 
      when :lparen; parse_expression_sequence
      else          parse_comparison
    end
    return ScopedSearch::QueryLanguage::AST::OperatorNode.new(:not, [negated_expression])
  end
  
  def parse_null_expression
    return ScopedSearch::QueryLanguage::AST::OperatorNode.new(next_token, [parse_value])
  end
  
  def parse_comparison
    next_token if peek_token == :comma # skip comma      
    return (String === peek_token) ? parse_infix_comparison : parse_prefix_comparison
  end
  
  def parse_prefix_comparison
    return ScopedSearch::QueryLanguage::AST::OperatorNode.new(next_token, [parse_value])
  end  

  def parse_infix_comparison
    lhs = parse_value
    return case peek_token
      when nil
        lhs
      when :comma
        next_token # skip comma
        lhs
      else
        if COMPARISON_OPERATORS.include?(peek_token)
          comparison_operator = next_token
          rhs = parse_value
          ScopedSearch::QueryLanguage::AST::OperatorNode.new(comparison_operator, [lhs, rhs])
        else
          lhs
        end
    end
  end  
  
  def parse_value
    raise ScopedSearch::Exception, "Value expected but found #{peek_token.inspect}" unless String === peek_token
    ScopedSearch::QueryLanguage::AST::LeafNode.new(next_token)
  end

  protected 
  
  def current_token
    @current_token
  end
  
  def peek_token(amount = 1)
    @tokens[amount - 1]
  end

  def next_token
    @current_token = @tokens.shift
  end  

end