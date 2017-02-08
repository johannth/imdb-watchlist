module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import String
import Json.Decode as Decode
import Table


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


type alias BuildInfo =
    { version : String
    , time : String
    , tier : String
    }


type alias Model =
    { movies : Maybe (List Movie)
    , buildInfo : BuildInfo
    , tableState : Table.State
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        model =
            { movies = Maybe.Nothing
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
    | SetTableState Table.State


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadWatchList (Err error) ->
            ( model
            , Cmd.none
            )

        LoadWatchList (Ok movies) ->
            ( { model | movies = Maybe.Just movies }
            , Cmd.none
            )

        SetTableState newState ->
            ( { model | tableState = newState }
            , Cmd.none
            )



-- VIEW


rootView : Model -> Html Msg
rootView { movies, tableState, buildInfo } =
    div [ id "content" ]
        [ h1 [ id "title" ] [ text "Watchlist" ]
        , div [ id "list" ]
            [ case movies of
                Maybe.Nothing ->
                    text "Loading..."

                Maybe.Just movies ->
                    Table.view config tableState movies
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
            , movieRunTimeColumn
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


movieRunTimeColumn : Table.Column Movie Msg
movieRunTimeColumn =
    let
        extractRunTimeWithDefault movie =
            Maybe.withDefault 0 movie.runTime

        runTimeToString movie =
            Maybe.withDefault "?" (Maybe.map toString movie.runTime)
    in
        Table.customColumn
            { name = "Run Time"
            , viewData = runTimeToString
            , sorter = Table.increasingOrDecreasingBy extractRunTimeWithDefault
            }



-- HTTP


type alias Movie =
    { id : String
    , title : String
    , imdbUrl : String
    , runTime : Maybe Int
    }


apiUrl : String -> String
apiUrl path =
    "http://localhost:3001" ++ path


getWatchlistData : String -> Cmd Msg
getWatchlistData userId =
    Http.send LoadWatchList <|
        Http.get (apiUrl ("/api/watchlist?userId=" ++ userId)) decodeWatchlist


decodeWatchlist : Decode.Decoder (List Movie)
decodeWatchlist =
    decodeWatchlistDataIntoRows


decodeWatchlistDataIntoRows : Decode.Decoder (List Movie)
decodeWatchlistDataIntoRows =
    Decode.at [ "list", "movies" ] (Decode.list decodeWatchlistRowIntoMovie)


decodeWatchlistRowIntoMovie : Decode.Decoder Movie
decodeWatchlistRowIntoMovie =
    Decode.map4 Movie
        (Decode.at [ "id" ] Decode.string)
        (Decode.at [ "primary", "title" ] Decode.string)
        decodeImdbUrl
        decodeMovieRunTime


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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
