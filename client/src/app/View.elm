module View exposing (rootView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Table
import Dict
import Types exposing (..)
import State


rootView : Model -> Html Msg
rootView { list, movies, tableState, buildInfo } =
    div [ id "content" ]
        [ h1 [ id "title" ] [ text "Watchlist" ]
        , div [ id "list" ]
            [ case list of
                Nothing ->
                    text "Loading..."

                Just list ->
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
