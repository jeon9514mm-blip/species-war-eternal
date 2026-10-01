# Adapted from gdtoolkit: Copyright (c) 2019 Pawel Lampe, MIT license.
from collections import defaultdict
from lark.indenter import Indenter
from lark.lexer import Token

class GDScriptIndenter(Indenter):
    NL_type = '_NL'
    OPEN_PAREN_types = ['LPAR','LSQB','LBRACE']
    CLOSE_PAREN_types = ['RPAR','RSQB','RBRACE']
    LAMBDA_LINE_EXTENSION_types = ['IF','WHILE','FOR','MATCH']
    LAMBDA_SEPARATOR_types = ['COMMA']
    INDENT_type = '_INDENT'
    DEDENT_type = '_DEDENT'
    tab_len = 4
    def __init__(self):
        super().__init__()
        self.processed_tokens = []
        self.undedented_lambdas_at_paren_level = defaultdict(int)
    def handle_NL(self, token):
        if self.paren_level > 0:
            yield from self._handle_NL_in_parens(token)
        else:
            for produced_token in super().handle_NL(token):
                if produced_token.type == self.DEDENT_type:
                    yield Token(self.DEDENT_type, None, None, token.line, None, token.line)
                    yield token
                else:
                    yield produced_token
    def _process(self, stream):
        self.processed_tokens = []
        self.undedented_lambdas_at_paren_level = defaultdict(int)
        had_newline = False
        for produced_token in super()._process(self._record_stream(stream)):
            if produced_token.type in self.CLOSE_PAREN_types or produced_token.type in self.LAMBDA_SEPARATOR_types:
                while self.undedented_lambdas_at_paren_level[self.paren_level] > 0:
                    yield from self._dedent_lambda_at_token(had_newline, produced_token)
                    had_newline = False
            had_newline = produced_token.type == self.NL_type
            yield produced_token
    def _record_stream(self, stream):
        for token in stream:
            self.processed_tokens.append(token)
            yield token
    def _in_multiline_lambda(self):
        return self.undedented_lambdas_at_paren_level[self.paren_level] > 0
    def _handle_NL_in_parens(self, token):
        indent_str = token.rsplit('\n', 1)[1]
        indent = indent_str.count(' ') + indent_str.count('\t') * self.tab_len
        if indent > self.indent_level[-1] and (self._current_token_is_just_after_lambda_header() or self._in_multiline_lambda()):
            self.indent_level.append(indent)
            self.undedented_lambdas_at_paren_level[self.paren_level] += 1
            yield token
            yield Token.new_borrow_pos(self.INDENT_type, indent_str, token)
        elif indent <= self.indent_level[-1] and self._in_multiline_lambda():
            yield token
            while indent < self.indent_level[-1] and self._in_multiline_lambda():
                self.indent_level.pop()
                self.undedented_lambdas_at_paren_level[self.paren_level] -= 1
                yield Token(self.DEDENT_type, None, None, token.line, None, token.line)
                if self._in_multiline_lambda():
                    yield token
    def _dedent_lambda_at_token(self, had_newline, token):
        self.indent_level.pop()
        self.undedented_lambdas_at_paren_level[self.paren_level] -= 1
        if not had_newline:
            yield Token.new_borrow_pos(self.NL_type, 'N/A', token)
        yield Token.new_borrow_pos(self.DEDENT_type, 'N/A', token)
    def _current_token_is_just_after_lambda_header(self):
        extra_rpars = [0]
        pattern_functions = [lambda t:t.type == 'COLON', lambda t:t.type == 'RPAR',lambda t:t.type == 'LPAR' and extra_rpars[0]==0,lambda t:t.type == 'FUNC']
        def lpar_accept_function(token):
            if token.type == 'RPAR': extra_rpars[0] += 1
            elif token.type == 'LPAR':
                if extra_rpars[0] <= 0: return False
                extra_rpars[0] -= 1
            return True
        accept_functions = [lambda t:t.type == '_NL', lambda t:t.type in ['_NL','TYPE_HINT'] or t.value == '->', lpar_accept_function,lambda t:t.type in ['_NL','NAME']]
        i = 0
        for token in reversed(self.processed_tokens):
            if i >= len(pattern_functions): return True
            if pattern_functions[i](token):
                i += 1
                continue
            if not accept_functions[i](token): return False
        return i >= len(pattern_functions)
