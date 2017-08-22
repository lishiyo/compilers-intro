require "./instruction.cr"

# Parsing is a supertype of lexing.
# The parser consumes the token stream generated from lexing:
# - determines the semantic meaning behind them 
# - enforces syntactic rules
# => outputs array of Instructions to interpreter
class Parser < Lexer
  # The list of instructions parsed from the source code. This is what will be fed to the interpreter.
  property instructions : Array(Instruction) = [] of Instruction

  # Advance through the token stream until a significant token is encountered.
  # This abstraction allows the rest of the parser to quietly ignore whitespace and other insignificant tokens.
  def advance
    while read_token.type == TokenType::WHITESPACE; end
    current_token # set current_token to next non-whitespace char
  end

  # Check if the current token matches the given type and return
  # truthy if it does. Additionally, if the type matches, automatically
  # advance to the next significant token.
  def accept(type : TokenType)
    token = current_token
    if current_token.type == type
      advance # advances the current_token to next
      token
    end
  end

  # Similar to `accept`, but raise an error if the type does not match.
  def expect(type : TokenType)
    accept(type) || raise "Expected #{type}, got #{current_token.type}."
  end

  def parse_program
    advance
    until @current_token.type == TokenType::EOF
      parse_statement
    end
  end

  def parse_statement
    if accept(TokenType::AT) # current was @
      parse_assignment
    else
      parse_expr
    end
  end

  # @vartoset = 4
  # PUSH, STORE
  def parse_assignment
    name = expect(TokenType::NAME) 
    expect(TokenType::EQUAL)
    parse_expr
    instructions << Instruction.new(InstructionType::STORE, [name.value])
  end

  def parse_expr
    parse_term # check multiply and divide
    if accept(TokenType::PLUS)
      parse_expr
      instructions << Instruction.new(InstructionType::ADD)
    elsif accept(TokenType::MINUS)
      parse_expr
      instructions << Instruction.new(InstructionType::SUBTRACT)
    end
  end

  def parse_term
    parse_factor # check parens and numbers
    if accept(TokenType::STAR)
      parse_term
      instructions << Instruction.new(InstructionType::MULTIPLY)
    elsif accept(TokenType::SLASH)
      parse_term
      instructions << Instruction.new(InstructionType::DIVIDE)
    end
  end

  # (2 * 4) + alpha => factor, term, factor, factor, expr, factor
  # PUSH(2), PUSH(4), MULTIPLY, LOAD(alpha), ADD 
  def parse_factor
    if accept(TokenType::LPAREN)
      parse_expr
      expect(TokenType::RPAREN)
    elsif name = accept(TokenType::NAME)
      instructions << Instruction.new(InstructionType::LOAD, [name.value])
    elsif number = accept(TokenType::NUMBER)
      instructions << Instruction.new(InstructionType::PUSH, [number.value])
    else
      raise "Unexpected token #{current_token.inspect}"
    end
  end
end
