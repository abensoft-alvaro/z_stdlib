%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2011 Marc Worrell
%% @doc Simple temporary file handling, deletes the file when the calling process stops or crashes.

%% Copyright 2010 Marc Worrell
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%% 
%%     http://www.apache.org/licenses/LICENSE-2.0
%% 
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(z_tempfile).
-author("Marc Worrell <marc@worrell.nl>").

-export([
	new/0,
	new/1,
	tempfile/0,
	tempfile/1,
	is_tempfile/1,
	temppath/0
]).

-type filename() :: string().

%% @doc Return a new unique filename, start a monitoring process to clean it up after use.
-spec new() -> filename().
new() ->
	new("").

%% @doc Return a new unique filename, start a monitoring process to clean it up after use.
-spec new(string()) -> filename().
new(Extension) ->
	Filename = tempfile(Extension),
	OwnerPid = self(),
	Pid = erlang:spawn_link(fun() -> cleanup(Filename, OwnerPid) end),
	receive
		{is_monitoring, Pid} -> Filename
	end.


%% @doc Monitoring process, delete file when requesting process stops or crashes
cleanup(Filename, OwnerPid) ->
	process_flag(trap_exit, true),
	MRef = erlang:monitor(process, OwnerPid),
	OwnerPid ! {is_monitoring, self()},
	receive
		{'EXIT', OwnerPid, _Reason} ->
			erlang:demonitor(MRef),
			file:delete(Filename);
		{'DOWN', _MRef, process, OwnerPid, _Reason} ->
			file:delete(Filename)
	end.

%% @doc return a unique temporary filename.
-spec tempfile() -> filename().
tempfile() ->
	tempfile("").

%% @doc return a unique temporary filename with a set extension.
-spec tempfile(string()) -> filename().
tempfile(Extension) ->
	A = crypto:rand_uniform(1,100000000),
	B = crypto:rand_uniform(1,100000000),
    Filename = filename:join(temppath(), lists:flatten(io_lib:format("ztmp-~s-~p.~p~s",[node(),A,B,Extension]))),
    case filelib:is_file(Filename) of
    	true -> tempfile(Extension);
    	false -> Filename
    end.

%% @doc Check if the file is a temporary filename.
-spec is_tempfile(filename()) -> boolean().
is_tempfile(Filename) ->
	lists:prefix(filename:join(temppath(), "ztmp-"), Filename). 

%% @doc Returns the path where to store temporary files.
-spec temppath() -> filename().
temppath() ->
    lists:foldl(fun(false, Fallback) -> Fallback;
                   (Good, _) -> Good end,
                "/tmp",
                [os:getenv("TMP"), os:getenv("TEMP")]).
