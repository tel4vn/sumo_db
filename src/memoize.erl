%% Copyright (c) 2008 Nick Gerakines <nick@gerakines.net>
%%
%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without
%% restriction, including without limitation the rights to use,
%% copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following
%% conditions:
%%
%% The above copyright notice and this permission notice shall be
%% included in all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
%% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
%% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
%% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
%% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
%% OTHER DEALINGS IN THE SOFTWARE.
%%
%% @author Nick Gerakines <nick@gerakines.net>
%% @copyright 2008 Nick Gerakines
%% @version 0.1
%% @doc A simple memoize gen_server.
-module(memoize).

-behaviour(gen_server).

-export([call/2, start_link/0]).

-export([
         init/1, terminate/2, code_change/3,
         handle_call/3, handle_cast/2, handle_info/2
        ]).

%% @doc the public interface to this module.
-spec call(fun(), list()) -> term().
call(Fun, Args) ->
  gen_server:call(?MODULE, {Fun, Args}, infinity).

-spec start_link() -> term().
start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec init(term()) -> term().
init(_) ->
  create_ets(),
  {ok, #{}}.

create_ets() ->
  case ets:info(?MODULE) of
    undefined ->
      ets:new(?MODULE, [ordered_set, public, named_table,
                        {write_concurrency,true},
                        {read_concurrency,true}, compressed]);
    _ -> ok
  end.

-spec handle_call(term(), term(), term()) -> term().
handle_call({Fun, Args}, _From, State) ->
  Key = erlang:phash2({Fun, Args}),
  Value = case ets:lookup(?MODULE, Key) of
            None when None == [] orelse None == false ->
              Result = apply(Fun, Args),
              true = ets:insert_new(?MODULE, {Key, Result}),
              Result;
            [{_, Memoized}] ->
              Memoized
          end,
  {reply, Value, State};
handle_call(stop, _From, State) ->
  {stop, normalStop, State};
handle_call(_, _From, State) ->
  {reply, error, State}.

-spec handle_cast(term(), term()) -> term().
handle_cast(_Msg, State) -> {noreply, State}.

-spec handle_info(term(), term()) -> term().
handle_info(_Info, State) -> {noreply, State}.

-spec terminate(term(), term()) -> ok.
terminate(_Reason, _State) -> ok.

-spec code_change(term(), term(), term()) -> term().
code_change(_OldVsn, State, _Extra) -> {ok, State}.
