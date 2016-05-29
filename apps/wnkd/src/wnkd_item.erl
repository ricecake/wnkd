-module(wnkd_item).

-export([
	create/1
]).

-define(THUMB_WIDTH, 320).
-define(FULL_WIDTH, 640).

-include_lib("erl_img/include/erl_img.hrl").

create(#{ <<"images">> := Images, <<"primary">> := PrimaryImage } = Data) ->
	{ok, ID} = insert_item(Data),
	process_images(ID, PrimaryImage, maps:to_list(Images)),
	ok.

process_images(_ID, _PrimaryImage, []) -> ok;
process_images({ID, UUID}, PrimaryImage, [{Title, #{ <<"data">> := Data }} |Rest]) ->
	{ok, Image} = erl_img:load(base64:decode(Data)),
	Primary = PrimaryImage =:= Title,
	FullImage = proportionalize(?FULL_WIDTH, Image),
	{ok, 1, _, [{FullUUID}]} = pgapp:equery(wnkd,
		"insert into photo (item, featured, type, role) values ($1, $2, $3, $4) returning uuid",
		[ID, Primary, <<"png">>, <<"fullsize">>]
	),
	_ThumbImage = proportionalize(?THUMB_WIDTH, FullImage),
	{ok, 1, _, [{ThumbUUID}]} = pgapp:equery(wnkd,
		"insert into photo (item, featured, type, role) values ($1, $2, $3, $4) returning uuid",
		[ID, Primary, <<"png">>, <<"thumbnail">>]
	),
	io:format("~p~n", [{Title, FullUUID, ThumbUUID}]),
	process_images({ID, UUID}, PrimaryImage, Rest).


proportionalize(MaxWidth, #erl_image{width = Width} = Image) ->
	ScaleFactor = MaxWidth / Width,
	erl_img:scale(Image, ScaleFactor).

insert_item(#{<<"title">> := Name, <<"category">> := Category, <<"description">> := Description}) ->
	{ok, 1, _, [{ID, UUID}]} = pgapp:equery(wnkd,
		"insert into item (name, category, full_description) values ($1, $2, $3) returning id, uuid",
		[Name, Category, Description]
	),
	{ok, {ID, UUID}}.
