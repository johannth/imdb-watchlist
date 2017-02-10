module View exposing (rootView)

import Html exposing (..)
import Html.Attributes exposing (..)
import Table
import Dict
import Types exposing (..)


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
            , streamColumn "Netflix" .netflixUrl
            , streamColumn "HBO" .hboUrl
            , streamColumn "Amazon" .amazonUrl
            , streamColumn "iTunes" .itunesUrl
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
        , viewData = \movie -> linkCell movie.title (Just movie.imdbUrl)
        , sorter = Table.increasingOrDecreasingBy .title
        }


streamColumn : String -> (Movie -> Maybe String) -> Table.Column Movie Msg
streamColumn name accessor =
    Table.veryCustomColumn
        { name = name
        , viewData = \movie -> linkCell "X" (accessor movie)
        , sorter = Table.increasingBy (\movie -> Maybe.withDefault "" (accessor movie))
        }


linkCell : String -> Maybe String -> Table.HtmlDetails Msg
linkCell title url =
    Table.HtmlDetails []
        [ case url of
            Just url ->
                a [ href url, target "_blank" ] [ text title ]

            Nothing ->
                span [] []
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


maybeHasValue : Maybe a -> Bool
maybeHasValue maybeValue =
    case maybeValue of
        Just _ ->
            True

        Nothing ->
            False


calculateStreamabilityWeight : Movie -> Float
calculateStreamabilityWeight movie =
    if List.any maybeHasValue [ movie.netflixUrl, movie.hboUrl, movie.amazonUrl ] then
        1
    else if maybeHasValue movie.itunesUrl then
        0.9
    else
        0.1


calculatePriority : Movie -> Float
calculatePriority movie =
    let
        extractValueToFloat maybeInt =
            Maybe.withDefault 50 (Maybe.map toFloat maybeInt)

        streamabilityWeight =
            calculateStreamabilityWeight movie

        runTimeWeight =
            1 / 5

        normalizedRunTime =
            90 * (1 / (extractValueToFloat movie.runTime + 90))

        metascoreWeight =
            1 / 5

        tomatoMeterWeight =
            1 / 5

        imdbRatingWeight =
            1 / 5

        bechdelWeight =
            1 / 5

        normalizedBechdel =
            extractValueToFloat (Maybe.map .rating movie.bechdelRating) / 3
    in
        streamabilityWeight
            * (metascoreWeight
                * (extractValueToFloat movie.metascore)
                + tomatoMeterWeight
                * (extractValueToFloat movie.rottenTomatoesMeter)
                + imdbRatingWeight
                * (extractValueToFloat movie.imdbRating)
                + bechdelWeight
                * normalizedBechdel
                + runTimeWeight
                * normalizedRunTime
              )


priorityColumn : Table.Column Movie Msg
priorityColumn =
    Table.customColumn
        { name = "Priority"
        , viewData = calculatePriority >> toString
        , sorter = Table.decreasingOrIncreasingBy calculatePriority
        }
