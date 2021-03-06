%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%%% @doc
%%% Node health statistics
%%% @end

%% @copyright Copyright 2012-2012 Chef Software, Inc. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License. You may obtain
%% a copy of the License at
%%
%% http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied. See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
-module(pushy_node_stats).

-compile([{parse_transform, lager_transform}]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-record(metric, {node_pid :: pid(),
                 avg=down_threshold() * 2 :: float(),
                 interval_start=pushy_time:timestamp() :: number(),
                 heartbeats=1 :: non_neg_integer()}).

%% These two weights must total to 1.0
-define(NOW_WEIGHT, (1.0/decay_window())).
-define(HISTORY_WEIGHT, (1.0-?NOW_WEIGHT)).

-export([init/0,
         heartbeat/1,
         stop/0,
         scan/0]).

-spec init() -> ok.
init() ->
    _Tid = ets:new(?MODULE, [set, public, named_table, {keypos, 2},
                             {write_concurrency, true}, {read_concurrency, true}]),
    ok.

%% This exists to make eunit tests less painful to write.
-spec stop() -> ok.
stop() ->
    true = ets:delete(?MODULE),
    ok.


-spec heartbeat(pid()) -> ok | should_die.
heartbeat(NodePid) ->
    case ets:lookup(?MODULE, NodePid) of
        [] ->
            ets:insert_new(?MODULE, #metric{node_pid=NodePid}),
            ok;
        [Node] ->
            Node1 = hb(Node),
            case evaluate_node_health(Node1) of
                {reset, Node2} ->
                    ets:insert(?MODULE, Node2),
                    ok;
                {should_die, _Node2} ->
                    ets:delete_object(?MODULE, Node1),
                    should_die
            end
    end.

-spec scan() -> ok.
scan() ->
    ets:safe_fixtable(?MODULE, true),
    try
        scan(ets:first(?MODULE))
    after
        %% Make sure we unfix the table even
        %% if an error was thrown
        ets:safe_fixtable(?MODULE, false)
    end.

scan('$end_of_table') ->
    ok;
scan(NodePid) ->
    [Node] = ets:lookup(?MODULE, NodePid),
    case evaluate_node_health(Node) of
        {reset, Node1} ->
            ets:insert(?MODULE, Node1),
            ok;
        {should_die, _Node1} ->
            ets:delete_object(?MODULE, Node),
            NodePid ! should_die
    end,
    scan(ets:next(?MODULE, NodePid)).

hb(#metric{}=Node) ->
    Node1 = maybe_advance_interval(Node),
    Node1#metric{heartbeats=Node1#metric.heartbeats + 1}.


-spec evaluate_node_health(Node::#metric{}) -> {reset | should_die, #metric{} }.
evaluate_node_health(Node) ->
    Node1 = maybe_advance_interval(Node),
    #metric{node_pid=Pid, avg=NAvg} = Node1,
    case NAvg < down_threshold() of
        true ->
            lager:debug("Killing Node: ~p~n", [Pid]),
            {should_die, Node1};
        false ->
            lager:debug("Resetting Node: ~p~n", [Pid]),
            {reset, Node1}
    end.

heartbeat_interval() ->
    %% Heartbeat interval is specified in milliseconds, but we keep time in microseconds.
    envy:get(pushy, heartbeat_interval, integer) * 1000.

down_threshold() ->
    envy:get(pushy, down_threshold, number).

decay_window() ->
    envy:get(pushy, decay_window, integer).

%% Advance the heartbeat interval to include the current time.
%%
%% If it has been a while since we updated (as when we haven't received a heartbeat), there
%% may be several empty intervals between the last updated interval and the one we are in
%% now.
%%
maybe_advance_interval(#metric{interval_start=StartI} = M) ->
    ICount = (pushy_time:timestamp() - StartI) div heartbeat_interval(),
    advance_interval(M, ICount).

advance_interval(M, 0) ->
    M;
advance_interval(#metric{avg=Avg, interval_start=StartI, heartbeats=Hb} = M, ICount) ->
    NextI = StartI + heartbeat_interval() * ICount,
    %% The first interval may have accumulated heartbeats. Later intervals will not and can be
    %% aggregated into one step using pow.
    NAvg = ((Avg * ?HISTORY_WEIGHT) + (Hb * ?NOW_WEIGHT)) * math:pow(?HISTORY_WEIGHT, ICount-1),
    folsom_metrics:notify(app_metric(<<"health">>), NAvg, histogram),
    folsom_metrics:notify(app_metric(<<"interval">>), ICount, histogram),
    folsom_metrics:notify(app_metric(<<"heartbeat">>), Hb, histogram),
    M#metric{avg=NAvg, interval_start=NextI, heartbeats=0}.

app_metric(Name) ->
    pushy_metrics:app_metric(?MODULE, Name).
