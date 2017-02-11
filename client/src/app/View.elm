module View exposing (rootView)

import Table
import Set
import Dict
import State
import Json.Decode as Decode
import Html.Events
import Html exposing (..)
import Html.Attributes exposing (..)
import Types exposing (..)


rootView : Model -> Html Msg
rootView { imdbUserIdInputCurrentValue, lists, movies, tableState, buildInfo } =
    let
        list =
            Dict.values lists
                |> List.map Set.fromList
                |> List.foldl Set.union Set.empty
                |> Set.toList
    in
        div [ id "content" ]
            [ h1 [ id "title" ] [ text "Watchlist" ]
            , imdbUserIdTextInput imdbUserIdInputCurrentValue
            , div [ id "imdb-users" ] (Dict.keys lists |> List.map imdbUserIdView)
            , div [ id "list" ]
                [ case list of
                    [] ->
                        text
                            (if Dict.size lists > 0 then
                                "Loading..."
                             else
                                ""
                            )

                    list ->
                        let
                            expandedList =
                                List.filterMap (\movieId -> Dict.get movieId movies) list
                        in
                            Table.view config tableState expandedList
                ]
            , div [ id "footer" ]
                [ buildInfoView buildInfo
                ]
            ]


config : Table.Config Movie Msg
config =
    Table.config
        { toId = .id
        , toMsg = SetTableState
        , columns =
            [ movieTitleColumn
            , maybeIntColumn "Run Time (min)" .runTime
            , maybeIntColumn "Metascore" .metascore
            , maybeIntColumn "Tomatometer" .rottenTomatoesMeter
            , maybeIntColumn "Imdb Rating" .imdbRating
            , maybeIntColumn "Bechdel" (\movie -> Maybe.map .rating movie.bechdelRating)
            , streamColumn "Netflix" .netflix
            , streamColumn "HBO" .hbo
            , streamColumn "Amazon" .amazon
            , streamColumn "iTunes" .itunes
            , priorityColumn
            ]
        }


buildInfoView : BuildInfo -> Html Msg
buildInfoView buildInfo =
    text ("Version: " ++ buildInfo.time ++ " " ++ (String.slice 0 8 buildInfo.version) ++ "-" ++ buildInfo.tier)


movieTitleColumn : Table.Column Movie Msg
movieTitleColumn =
    Table.veryCustomColumn
        { name = "Title"
        , viewData = \movie -> linkCell movie.title movie.imdbUrl
        , sorter = Table.increasingOrDecreasingBy .title
        }


cellForOffer : Maybe JustWatchOffer -> Table.HtmlDetails Msg
cellForOffer offer =
    case offer of
        Just (Flatrate _ url _) ->
            linkCell "Free" url

        Just (Buy _ url _ price) ->
            linkCell ("$" ++ (toString price)) url

        Just (Rent _ url _ price) ->
            linkCell ("$" ++ (toString price)) url

        Nothing ->
            Table.HtmlDetails [] []


streamColumn : String -> (Movie -> Maybe JustWatchOffer) -> Table.Column Movie Msg
streamColumn name accessor =
    Table.veryCustomColumn
        { name = name
        , viewData = cellForOffer << accessor
        , sorter = Table.unsortable
        }


linkCell : String -> String -> Table.HtmlDetails Msg
linkCell title url =
    Table.HtmlDetails []
        [ a [ href url, target "_blank" ] [ text title ]
        ]


maybeIntColumn : String -> (Movie -> Maybe Int) -> Table.Column Movie Msg
maybeIntColumn name accessor =
    let
        extractWithDefault movie =
            Maybe.withDefault -1 (accessor movie)

        valueToString movie =
            Maybe.withDefault "?" (Maybe.map toString (accessor movie))
    in
        Table.customColumn
            { name = name
            , viewData = valueToString
            , sorter = Table.decreasingOrIncreasingBy extractWithDefault
            }


priorityColumn : Table.Column Movie Msg
priorityColumn =
    Table.customColumn
        { name = "Priority"
        , viewData = State.calculatePriority >> toString
        , sorter = Table.decreasingOrIncreasingBy State.calculatePriority
        }


imdbUserIdView : String -> Html Msg
imdbUserIdView imdbUserId =
    span [ class "imdb-user-link" ]
        [ a [ target "_blank", href ("http://www.imdb.com/user/" ++ imdbUserId ++ "/watchlist?view=detail") ]
            [ text imdbUserId
            ]
        , a [ class "imdb-user-remove-button", href "#", Html.Events.onClick (ClearList imdbUserId) ] [ text "X" ]
        ]


imdbUserIdTextInput : String -> Html Msg
imdbUserIdTextInput currentValue =
    let
        properties =
            [ placeholder "Enter IMDB userId", onEnter LookupWatchList, Html.Events.onInput ImdbUserIdInput, value currentValue ]
    in
        div [ id "imdb-user-id-input" ]
            [ input properties []
            ]


onEnter : (String -> Msg) -> Attribute Msg
onEnter msg =
    let
        isEnter : Int -> Decode.Decoder String
        isEnter code =
            if code == 13 then
                Decode.succeed "ENTER pressed"
            else
                Decode.fail "not ENTER"

        decodeEnter =
            Decode.andThen isEnter Html.Events.keyCode

        decodeEnterWithValue : Decode.Decoder Msg
        decodeEnterWithValue =
            Decode.map2 (\key value -> msg value)
                decodeEnter
                Html.Events.targetValue
    in
        Html.Events.on "keydown" decodeEnterWithValue
