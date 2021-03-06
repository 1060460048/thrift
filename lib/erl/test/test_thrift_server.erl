%%
%% Licensed to the Apache Software Foundation (ASF) under one
%% or more contributor license agreements. See the NOTICE file
%% distributed with this work for additional information
%% regarding copyright ownership. The ASF licenses this file
%% to you under the Apache License, Version 2.0 (the
%% "License"); you may not use this file except in compliance
%% with the License. You may obtain a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied. See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%

-module(test_thrift_server).

-export([go/0, go/1, start_link/2, handle_function/2]).

-include("gen-erl/thrift_test_types.hrl").

-record(options, {port = 9090,
                  server_opts = []}).

parse_args(Args) -> parse_args(Args, #options{}).
parse_args([], Opts) -> Opts;
parse_args([Head | Rest], Opts) ->
    NewOpts =
        case catch list_to_integer(Head) of
            Port when is_integer(Port) ->
                Opts#options{port = Port};
            _Else ->
                case Head of
                    "framed" ->
                        Opts#options{server_opts = [{framed, true} | Opts#options.server_opts]};
                    "" ->
                        Opts;
                    _Else ->
                        erlang:error({bad_arg, Head})
                end
        end,
    parse_args(Rest, NewOpts).

go() -> go([]).
go(Args) ->
    #options{port = Port, server_opts = ServerOpts} = parse_args(Args),
    spawn(fun() -> start_link(Port, ServerOpts), receive after infinity -> ok end end).

start_link(Port, ServerOpts) ->
    thrift_socket_server:start([{handler, ?MODULE},
                                {service, thriftTest_thrift},
                                {port, Port}] ++
                               ServerOpts).


handle_function(testVoid, {}) ->
    io:format("testVoid~n"),
    ok;

handle_function(testString, {S}) when is_binary(S) ->
    io:format("testString: ~p~n", [S]),
    {reply, S};

handle_function(testByte, {I8}) when is_integer(I8) ->
    io:format("testByte: ~p~n", [I8]),
    {reply, I8};

handle_function(testI32, {I32}) when is_integer(I32) ->
    io:format("testI32: ~p~n", [I32]),
    {reply, I32};

handle_function(testI64, {I64}) when is_integer(I64) ->
    io:format("testI64: ~p~n", [I64]),
    {reply, I64};

handle_function(testDouble, {Double}) when is_float(Double) ->
    io:format("testDouble: ~p~n", [Double]),
    {reply, Double};

handle_function(testBinary, {S}) when is_binary(S) ->
    io:format("testBinary: ~p~n", [S]),
    {reply, S};

handle_function(testStruct,
                {Struct = #'Xtruct'{string_thing = String,
                                 byte_thing = Byte,
                                 i32_thing = I32,
                                 i64_thing = I64}})
when is_binary(String),
     is_integer(Byte),
     is_integer(I32),
     is_integer(I64) ->
    io:format("testStruct: ~p~n", [Struct]),
    {reply, Struct};

handle_function(testNest,
                {Nest}) when is_record(Nest, 'Xtruct2'),
                             is_record(Nest#'Xtruct2'.struct_thing, 'Xtruct') ->
    io:format("testNest: ~p~n", [Nest]),
    {reply, Nest};

handle_function(testMap, {Map}) ->
    io:format("testMap: ~p~n", [dict:to_list(Map)]),
    {reply, Map};

handle_function(testSet, {Set}) ->
    true = sets:is_set(Set),
    io:format("testSet: ~p~n", [sets:to_list(Set)]),
    {reply, Set};

handle_function(testList, {List}) when is_list(List) ->
    io:format("testList: ~p~n", [List]),
    {reply, List};

handle_function(testEnum, {Enum}) when is_integer(Enum) ->
    io:format("testEnum: ~p~n", [Enum]),
    {reply, Enum};

handle_function(testTypedef, {UserID}) when is_integer(UserID) ->
    io:format("testTypedef: ~p~n", [UserID]),
    {reply, UserID};

handle_function(testMapMap, {Hello}) ->
    io:format("testMapMap: ~p~n", [Hello]),

    PosList = [{I, I}   || I <- lists:seq(1, 5)],
    NegList = [{-I, -I} || I <- lists:seq(1, 5)],

    MapMap = dict:from_list([{4,  dict:from_list(PosList)},
                             {-4, dict:from_list(NegList)}]),
    {reply, MapMap};

handle_function(testInsanity, {Insanity}) when is_record(Insanity, 'Insanity') ->
    Hello = #'Xtruct'{string_thing = <<"Hello2">>,
                    byte_thing = 2,
                    i32_thing = 2,
                    i64_thing = 2},

    Goodbye = #'Xtruct'{string_thing = <<"Goodbye4">>,
                      byte_thing = 4,
                      i32_thing = 4,
                      i64_thing = 4},
    Crazy = #'Insanity'{
      userMap = dict:from_list([{?THRIFT_TEST_NUMBERZ_EIGHT, 8}]),
      xtructs = [Goodbye]
      },

    Looney = #'Insanity'{
      userMap = dict:from_list([{?THRIFT_TEST_NUMBERZ_FIVE, 5}]),
      xtructs = [Hello]
      },

    FirstMap = dict:from_list([{?THRIFT_TEST_NUMBERZ_TWO, Crazy},
                               {?THRIFT_TEST_NUMBERZ_THREE, Crazy}]),

    SecondMap = dict:from_list([{?THRIFT_TEST_NUMBERZ_SIX, Looney}]),

    Insane = dict:from_list([{1, FirstMap},
                             {2, SecondMap}]),

    io:format("Return = ~p~n", [Insane]),

    {reply, Insane};

handle_function(testMulti, Args = {Arg0, Arg1, Arg2, _Arg3, Arg4, Arg5})
  when is_integer(Arg0),
       is_integer(Arg1),
       is_integer(Arg2),
       is_integer(Arg4),
       is_integer(Arg5) ->

    io:format("testMulti(~p)~n", [Args]),
    {reply, #'Xtruct'{string_thing = <<"Hello2">>,
                    byte_thing = Arg0,
                    i32_thing = Arg1,
                    i64_thing = Arg2}};

handle_function(testException, {String}) when is_binary(String) ->
    io:format("testException(~p)~n", [String]),
    case String of
        <<"Xception">> ->
            throw(#'Xception'{errorCode = 1001,
                            message = String});
        _ ->
            ok
    end;

handle_function(testMultiException, {Arg0, Arg1}) ->
    io:format("testMultiException(~p, ~p)~n", [Arg0, Arg1]),
    case Arg0 of
        <<"Xception">> ->
            throw(#'Xception'{errorCode = 1001,
                                   message = <<"This is an Xception">>});
        <<"Xception2">> ->
            throw(#'Xception2'{errorCode = 2002,
                                    struct_thing =
                                    #'Xtruct'{string_thing = <<"This is an Xception2">>}});
        _ ->
            {reply, #'Xtruct'{string_thing = Arg1}}
    end;

handle_function(testOneway, {Seconds}) ->
    timer:sleep(1000 * Seconds),
    ok.
