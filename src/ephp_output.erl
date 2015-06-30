-module(ephp_output).
-author('manuel@altenwald.com').
-compile([warnings_as_errors]).

-include("ephp.hrl").

-type flush_handler() ::
    stdout | {io, io:device()} | function().

-type output_handler() :: undefined | function().

-record(state, {
    output = <<>> :: binary(),
    flush = true :: boolean(),
    flush_handler = stdout :: flush_handler(),
    output_handler :: output_handler(),
    global_context :: reference()
}).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([
    start_link/1,
    start_link/2,
    start_link/3,
    get/1,
    push/2,
    pop/1,
    size/1,
    flush/1,
    set_flush/2,
    set_handler/2,
    get_handler/1,
    destroy/1
]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link(Ctx) ->
    start_link(Ctx, true, stdout).

start_link(Ctx, Flush) ->
    start_link(Ctx, Flush, stdout).

start_link(Ctx, Flush, FlushHandler) ->
    Ref = make_ref(),
    erlang:put(Ref, #state{
        flush = Flush,
        flush_handler = FlushHandler,
        global_context = Ctx
    }),
    {ok, Ref}.

get_handler(Ref) ->
    #state{output_handler=Handler} = erlang:get(Ref),
    Handler.

set_handler(Ref, Handler) ->
    State = erlang:get(Ref),
    erlang:put(Ref, State#state{output_handler=Handler}),
    ok.

pop(Ref) ->
    #state{output=Output} = State = erlang:get(Ref),
    erlang:put(Ref, State#state{output = <<>>}),
    Output.

push(Ref, RawText) ->
    case erlang:get(Ref) of
    #state{flush=true, global_context=Ctx}=State ->
        Text = output_handler(Ctx, RawText, State#state.output_handler),
        flush_handler(Text, State#state.flush_handler);
    #state{flush=false, output=Output}=State ->
        erlang:put(Ref, State#state{output = <<Output/binary, RawText/binary>>})
    end,
    ok.

get(Ref) ->
    #state{output=Output} = erlang:get(Ref),
    Output.

set_flush(Ref, Flush) ->
    State = erlang:get(Ref),
    erlang:put(Ref, State#state{flush = Flush}),
    ok.

size(Ref) ->
    #state{output=Output} = erlang:get(Ref),
    byte_size(Output).

flush(Ref) ->
    State = do_flush(Ref),
    erlang:put(Ref, State),
    ok.

destroy(Ref) ->
    do_flush(Ref),
    erlang:erase(Ref).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

do_flush(Ref) ->
    #state{output=RawOutput, global_context=Ctx} = State = erlang:get(Ref),
    Output = output_handler(Ctx, RawOutput, State#state.output_handler),
    flush_handler(Output, State#state.flush_handler),
    State#state{output = <<>>}.

output_handler(_Ctx, Text, undefined) ->
    Text;

output_handler(Ctx, Text, OH) when is_function(OH, 2) ->
    OH(Ctx, Text).

flush_handler(Text, stdout) ->
    io:fwrite("~s", [Text]),
    ok;

flush_handler(Text, {io, FH}) ->
    io:fwrite(FH, "~s", [Text]),
    ok;

flush_handler(Text, FH) when is_function(FH, 1) ->
    FH(Text),
    ok.
