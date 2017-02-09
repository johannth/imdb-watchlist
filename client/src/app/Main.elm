module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import String
import Json.Decode as Decode
import Table
import Dict


-- Hot Loading Requires the program to accept flags


type alias Flags =
    { build_version : String
    , build_tier : String
    , build_time : String
    }


main : Program Flags Model Msg
main =
    Html.programWithFlags
        { init = init
        , view = rootView
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Movie =
    { id : String
    , title : String
    , imdbUrl : String
    , runTime : Maybe Int
    , metascore : Maybe Int
    , imdbRating : Maybe Int
    , bechdelRating : Maybe BechdelRating
    }


type alias BuildInfo =
    { version : String
    , time : String
    , tier : String
    }


type alias BechdelRating =
    { rating : Int
    , dubious : Bool
    }


type alias Model =
    { list : Maybe (List String)
    , movies : Dict.Dict String Movie
    , buildInfo : BuildInfo
    , tableState : Table.State
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { list = Maybe.Nothing
            , movies = Dict.empty
            , tableState = Table.initialSort "Title"
            , buildInfo = BuildInfo flags.build_version flags.build_time flags.build_tier
            }
    in
        ( model
        , getWatchlistData "ur10614064"
        )



-- UPDATE


type Msg
    = LoadWatchList (Result Http.Error (List Movie))
    | LoadBechdel String (Result Http.Error (Maybe BechdelRating))
    | SetTableState Table.State


combine : (a -> b) -> (a -> c) -> (a -> ( b, c ))
combine f g =
    \x -> ( f (x), g (x) )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadWatchList (Err error) ->
            ( model
            , Cmd.none
            )

        LoadWatchList (Ok watchListMovies) ->
            let
                list =
                    List.map .id watchListMovies

                newMovies =
                    Dict.fromList (List.map (combine .id identity) watchListMovies)
            in
                ( { model | list = Maybe.Just list, movies = Dict.union newMovies model.movies }
                , Cmd.batch (List.map getBechdelData list)
                )

        LoadBechdel imdbId (Err error) ->
            ( model
            , Cmd.none
            )

        LoadBechdel imdbId (Ok bechdelRating) ->
            let
                movie =
                    Dict.get imdbId model.movies
            in
                case movie of
                    Maybe.Just movie ->
                        let
                            movieWithBechdelRating =
                                { movie | bechdelRating = bechdelRating }

                            newMovies =
                                Dict.insert imdbId movieWithBechdelRating model.movies
                        in
                            ( { model | movies = newMovies }
                            , Cmd.none
                            )

                    Maybe.Nothing ->
                        ( model
                        , Cmd.none
                        )

        SetTableState newState ->
            ( { model | tableState = newState }
            , Cmd.none
            )



-- VIEW


rootView : Model -> Html Msg
rootView { list, movies, tableState, buildInfo } =
    div [ id "content" ]
        [ h1 [ id "title" ] [ text "Watchlist" ]
        , div [ id "list" ]
            [ case list of
                Maybe.Nothing ->
                    text "Loading..."

                Maybe.Just list ->
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
            , maybeIntColumn "Imdb Rating" .imdbRating
            , maybeIntColumn "Bechdel" (\movie -> Maybe.map .rating movie.bechdelRating)
            ]
        }


buildInfoView : BuildInfo -> Html Msg
buildInfoView buildInfo =
    text ("Version: " ++ buildInfo.time ++ " " ++ (String.slice 0 8 buildInfo.version) ++ "-" ++ buildInfo.tier)


movieTitleColumn : Table.Column Movie Msg
movieTitleColumn =
    Table.veryCustomColumn
        { name = "Title"
        , viewData = movieTitleCell
        , sorter = Table.increasingOrDecreasingBy .title
        }


movieTitleCell : Movie -> Table.HtmlDetails Msg
movieTitleCell { title, imdbUrl } =
    Table.HtmlDetails [] [ a [ href imdbUrl, target "_blank" ] [ text title ] ]


maybeIntColumn : String -> (Movie -> Maybe Int) -> Table.Column Movie Msg
maybeIntColumn name accessor =
    let
        extractWithDefault movie =
            Maybe.withDefault -1 (accessor (movie))

        valueToString movie =
            Maybe.withDefault "?" (Maybe.map toString (accessor (movie)))
    in
        Table.customColumn
            { name = name
            , viewData = valueToString
            , sorter = Table.increasingOrDecreasingBy extractWithDefault
            }



-- HTTP


apiUrl : String -> String
apiUrl path =
    "http://localhost:3001" ++ path


getWatchlistData : String -> Cmd Msg
getWatchlistData userId =
    Http.send LoadWatchList <|
        Http.get (apiUrl ("/api/watchlist?userId=" ++ userId)) decodeWatchlist


decodeWatchlist : Decode.Decoder (List Movie)
decodeWatchlist =
    Decode.at [ "list", "movies" ] (Decode.list decodeWatchlistRowIntoMovie)


decodeWatchlistRowIntoMovie : Decode.Decoder Movie
decodeWatchlistRowIntoMovie =
    let
        normalizeImdbRating rating =
            round (rating * 10)
    in
        Decode.map7 Movie
            (Decode.at [ "id" ] Decode.string)
            (Decode.at [ "primary", "title" ] Decode.string)
            decodeImdbUrl
            decodeMovieRunTime
            (Decode.maybe (Decode.at [ "ratings", "metascore" ] Decode.int))
            (Decode.maybe (Decode.map normalizeImdbRating (Decode.at [ "ratings", "rating" ] Decode.float)))
            (Decode.succeed Maybe.Nothing)


decodeImdbUrl : Decode.Decoder String
decodeImdbUrl =
    Decode.map (\path -> "http://www.imdb.com" ++ path)
        (Decode.at [ "primary", "href" ] Decode.string)


decodeMovieRunTime : Decode.Decoder (Maybe Int)
decodeMovieRunTime =
    Decode.map2 calculateMovieRunTime
        (Decode.maybe (Decode.at [ "metadata", "runtime" ] Decode.int))
        (Decode.maybe (Decode.at [ "metadata", "numberOfEpisodes" ] Decode.int))


calculateMovieRunTime : Maybe Int -> Maybe Int -> Maybe Int
calculateMovieRunTime maybeRunTime maybeNumberOfEpisodes =
    let
        numberOfEpisodes =
            Maybe.withDefault 1 maybeNumberOfEpisodes
    in
        Maybe.map (\runTime -> (runTime * numberOfEpisodes) // 60) maybeRunTime



-- BECHDEL


getBechdelData : String -> Cmd Msg
getBechdelData imdbId =
    Http.send (LoadBechdel imdbId) <|
        Http.get (apiUrl ("/api/bechdel?imdbId=" ++ imdbId)) decodeBechdel


decodeBechdel : Decode.Decoder (Maybe BechdelRating)
decodeBechdel =
    Decode.maybe
        (Decode.map2 BechdelRating
            (Decode.at [ "data", "rating" ] (Decode.string |> Decode.andThen decodeIntFromString))
            (Decode.at [ "data", "dubious" ] (Decode.string |> Decode.andThen decodeBoolFromInt))
        )


decodeIntFromString : String -> Decode.Decoder Int
decodeIntFromString value =
    case String.toInt value of
        Ok valueAsInt ->
            Decode.succeed valueAsInt

        Err message ->
            Decode.fail message


decodeBoolFromInt : String -> Decode.Decoder Bool
decodeBoolFromInt value =
    case value of
        "0" ->
            Decode.succeed False

        "1" ->
            Decode.succeed True

        _ ->
            Decode.fail ("Unable to decode Bool from value: " ++ (toString value))



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
