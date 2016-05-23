%%%-------------------------------------------------------------------
%%% @author chenshaobo0428
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 23. 五月 2016 14:07
%%%-------------------------------------------------------------------
-module(lager_logio_backend).
-author("chenshaobo0428").

-behaviour(gen_event).

-export([init/1, handle_call/2, handle_event/2, handle_info/2, terminate/2,
  code_change/3]).
-export([info/0]).
-record(state, {
  level :: {'mask', integer()},
  formatter :: atom(),
  format_config :: any(),
  node ="":: list(),
  log_connection::port()
}).


info()->
  lager:info("make some message").

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-compile([{parse_transform, lager_transform}]).
-endif.

%-include_lib("lager.hrl").
-define(TERSE_FORMAT, [time, " ", color, "[", severity, "] ", message]).

%% @private
init([Level]) -> % for backwards compatibility
  init([Level, {lager_default_formatter, [{eol, eol()}]}]);
init([Level, {Formatter, FormatterConfig}]) when is_atom(Formatter) ->
  Levels = lager_util:config_to_mask(Level),
  {ok,Socket}= init_logio("127.0.0.1",28777),
  {ok, #state{level = Levels,
    formatter = Formatter,
    format_config = FormatterConfig,
    node = erlang:atom_to_list(erlang:node()),log_connection = Socket}};
init(Level) ->
  init([Level, {lager_default_formatter, ?TERSE_FORMAT ++ [eol()]}]).


%% @private
handle_call(get_loglevel, #state{level = Level} = State) ->
  {ok, Level, State};
handle_call({set_loglevel, Level}, State) ->
  try lager_util:config_to_mask(Level) of
    Levels ->
      {ok, ok, State#state{level = Levels}}
  catch
    _:_ ->
      {ok, {error, bad_log_level}, State}
  end;
handle_call(_Request, State) ->
  {ok, ok, State}.

%% @private
handle_event({log, Message},
  #state{level = L, formatter = Formatter, format_config = FormatConfig, log_connection = Socket,node = Node} = State) ->
  case lager_util:is_loggable(Message, L, ?MODULE) of
    true ->
      D =  Formatter:format(Message, FormatConfig),
%%      +log|stream|node|message\r\n
      ok = gen_tcp:send(Socket,erlang:list_to_binary("+log|"++"log|" ++ Node ++ "|" ++  erlang:atom_to_list(lager_msg:severity(Message)) ++ "|" ++ D ++ "\r\n")),
      {ok, State};
    false ->
      {ok, State}
  end;
handle_event(_Event, State) ->
  {ok, State}.

%% @private
handle_info(_Info, State) ->
  {ok, State}.

%% @private
terminate(_Reason,_State ) ->
%%  gen_tcp:send(Socket,"-node|" ++ erlang:atom_to_list(erlang:node()) ++ "\r\n"),
  ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

eol() ->
  case application:get_env(lager, colored) of
    {ok, true} ->
      "\e[0m\r\n";
    _ ->
      "\r\n"
  end.

init_logio(Host,Port)->
  {ok,S} = gen_tcp:connect(Host,Port,[{active,false},{keepalive,true},binary]),
  {ok,S}.
