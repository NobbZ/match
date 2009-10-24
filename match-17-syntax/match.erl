-module(match).
-compile(export_all).

module(Name, Ast) ->
    module(Name, Ast, 1).

module(Name, Ast, EofLine) ->
    [{attribute,1,module,Name},
        {attribute,1,compile,export_all}] ++ Ast ++ [{eof, EofLine}].

function(Name, Line, Arity, Ast) ->
    {function, Line, Name, Arity, Ast}.

function_body(Pattern, Line, Body) ->
    {clause, Line, Pattern, [], Body}.

forms('=', Line, Ast1, Ast2) ->
  {match, Line, Ast1, Ast2};
forms('not' = Op, Line, Ast1, nil) ->
  {op, Line, Op, Ast1};
forms('-' = Op, Line, Ast1, nil) ->
  {op, Line, Op, Ast1};
forms('~', Line, Ast1, nil) ->
  {op, Line, 'bnot', Ast1};
forms('!', Line, Ast1, Ast2) ->
  {op, Line, 'bor', Ast1, Ast2};
forms('&', Line, Ast1, Ast2) ->
  {op, Line, 'band', Ast1, Ast2};
forms('^', Line, Ast1, Ast2) ->
  {op, Line, 'bxor', Ast1, Ast2};
% the code below is from reia (I would have written the same :P)
% changes on == and != and parameter order
forms('*' = Op, Line, Ast1, Ast2) ->
  {op, Line, Op, Ast1, Ast2};
forms('/' = Op, Line, Ast1, Ast2) ->
  {op, Line, Op, Ast1, Ast2};
forms('%', Line, Ast1, Ast2) ->
  {op, Line, 'rem', Ast1, Ast2};

%% Addition
forms('+' = Op, Line, Ast1, Ast2) ->
  {op, Line, Op, Ast1, Ast2};
forms('-' = Op, Line, Ast1, Ast2) ->
  {op, Line, Op, Ast1, Ast2};

%% Boolean operators
forms('and', Line, Ast1, Ast2) ->
  {op, Line, 'andalso', Ast1, Ast2};
forms('or', Line, Ast1, Ast2) ->
  {op, Line, 'orelse', Ast1, Ast2};

%% Comparison operators
forms('==', Line, Ast1, Ast2) ->
  {op, Line, '=:=', Ast1, Ast2};
forms('!=', Line, Ast1, Ast2) ->
  {op, Line, '=/=', Ast1, Ast2};
forms('<' = Op, Line, Ast1, Ast2) ->
  {op, Line, Op, Ast1, Ast2};
forms('>' = Op, Line, Ast1, Ast2) ->
  {op, Line, Op, Ast1, Ast2};
forms('>=' = Op, Line, Ast1, Ast2) ->
  {op, Line, Op, Ast1, Ast2};
forms('<=', Line, Ast1, Ast2) ->
  {op, Line, '=<', Ast1, Ast2}.
% until here code from reia

get_ast(From, String) ->
    Ast = lists:map(fun(Line) -> matches(Line) end, get_tree(From, String)),
    module(get_module_name(String), Ast).

get_code(Ast) ->
    {ok, _, Code} = compile:forms(Ast),
    Code.

build_module(ModuleName, Ast) ->
    {module, Module} = code:load_binary(ModuleName, ModuleName, get_code(Ast)),
    Module.

to_erlang(From, String) ->
    Ast = get_ast(From, String),
    erl_prettypr:format(erl_syntax:form_list(Ast)).

from_erlang(Name) ->
    {ok, Content} = file:read_file(Name),
    Program = binary_to_list(Content),
    {ok,Scanned,_} = erl_scan:string(Program),
    {ok,Parsed} = erl_parse:parse_form(Scanned),
    Parsed.

build(From, String) ->
    ModuleName = get_module_name(String),
    build_module(ModuleName, get_ast(From, String)).

compile(Name) ->
    Module = get_code(get_ast(file, Name)),
    {ok, Device} = file:open(get_module_beam_name(Name), [binary, write]),
    file:write(Device, Module).

get_tree(From, String) ->
    Tokens = get_lex(From, String),
    {ok, Tree} = parser:parse(Tokens),
    Tree.

get_lex(string, String) ->
    {ok, Tokens, _Endline} = lexer:string(String),
    Tokens;
get_lex(file, Name) ->
    {ok, Content} = file:read_file(Name),
    Program = binary_to_list(Content),
    {ok, Tokens, _Endline} = lexer:string(Program),
    Tokens.

get_module_name(String) ->
    [ModuleNameStr | _] = string:tokens(String, "."),
    list_to_atom(ModuleNameStr).

get_module_beam_name(String) ->
    [ModuleNameStr | _] = string:tokens(String, "."),
    string:concat(ModuleNameStr, ".beam").

matches([]) -> [];
matches([_|_] = List) -> matches_list(List);
matches({integer, _, _} = Ast) -> Ast;
matches({float, _, _} = Ast) -> Ast;
matches({atom, _, _} = Ast) -> Ast;
matches({string, _, _} = Ast) -> Ast;
matches({var, _, _} = Ast) -> Ast;
matches({nil, _} = Ast) -> Ast;
matches({cons, Line, A, B}) -> {cons, Line, matches(A), matches(B)};
matches({tuple, Line, A}) -> {tuple, Line, matches_list(A)};
matches({'+' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'-' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'*' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'/' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'%' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));

matches({'<' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'<=' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'==' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'>=' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'>' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'!=' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));

matches({'!' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'&' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'^' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));

matches({'and' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({'or' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));

matches({'not' = Op, Line, A}) -> forms(Op, Line, matches(A), nil);
matches({'~' = Op, Line, A}) -> forms(Op, Line, matches(A), nil);
matches({'+', _Line, A}) -> matches(A);
matches({'-' = Op, Line, A}) -> forms(Op, Line, matches(A), nil);
matches({'(', _Line, A}) -> matches(A);

matches({lc, Line, Exp, Generators}) -> {lc, Line, matches(Exp), matches_list(Generators)};
matches({generate, Line, For, In}) -> {generate, Line, matches(For), matches(In)};
matches({generate, Line, For, In, If}) -> {generate, Line, matches(For), matches(In), matches(If)};
matches({callatom, Line, [Atom], Args}) ->
    {call, Line, Atom, lists:map(fun(Arg) -> matches(Arg) end, Args)};
matches({callatom, Line, [Package, Function], Args}) ->
    {call, Line, {remote, Line, Package, Function}, lists:map(fun(Arg) -> matches(Arg) end, Args)};
matches({call, Line, A, Args}) ->
    {call, Line, matches(A), lists:map(fun(Arg) -> matches(Arg) end, Args)};
matches({'=' = Op, Line, A, B}) -> forms(Op, Line, matches(A), matches(B));
matches({fn, Line, Patterns}) ->
    {'fun', Line, match_fun_body(Patterns)};
matches({fun_def, Line, Name, {fn, _Line, Patterns}}) ->
    function(Name, Line, get_function_arity(Patterns), match_function_body(Patterns));
matches(Exp) -> {error, Exp}.

matches_list([]) -> [];
matches_list(Items) -> matches_list(Items, []).

matches_list([], Accum) -> lists:reverse(Accum);
matches_list([Head | Tail], Accum) -> matches_list(Tail, [matches(Head) | Accum]).

match_fun_body(Patterns) ->
    {clauses, match_function_body(Patterns)}.

match_function_body(Patterns) -> match_function_body(Patterns, []).

match_function_body([], Clauses) -> lists:reverse(Clauses);
match_function_body([Pattern | Patterns], Clauses) ->
     match_function_body(Patterns, [match_pattern(Pattern) | Clauses]).

match_pattern({pattern, {'(', Line, Args}, {'{', _, Body}}) ->
    function_body([matches(Arg) || Arg <- Args], Line, lists:map(fun(L) -> matches(L) end, Body)).

get_function_arity([]) -> 0;
get_function_arity([{pattern, {'(', _Line, Arguments}, _}|_T]) -> length(Arguments).

