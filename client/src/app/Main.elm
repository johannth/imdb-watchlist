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


type alias WatchListMovie =
    { id : String
    , title : String
    , imdbUrl : String
    , runTime : Maybe Int
    , metascore : Maybe Int
    , imdbRating : Maybe Int
    }


type alias Movie =
    { id : String
    , title : String
    , imdbUrl : String
    , runTime : Maybe Int
    , metascore : Maybe Int
    , rottenTomatoesMeter : Maybe Int
    , imdbRating : Maybe Int
    , bechdelRating : Maybe BechdelRating
    , netflixUrl : Maybe String
    , hboUrl : Maybe String
    , itunesUrl : Maybe String
    , amazonUrl : Maybe String
    }


type alias BuildInfo =
    { version : String
    , time : String
    , tier : String
    }


type JustWatchPresentationType
    = SD
    | HD


type JustWatchProvider
    = Amazon
    | ITunes
    | Netflix
    | HBO


type JustWatchOffer
    = Rent JustWatchProvider String JustWatchPresentationType Float
    | Buy JustWatchProvider String JustWatchPresentationType Float
    | Flatrate JustWatchProvider String JustWatchPresentationType


type alias JustWatchScore =
    { providerType : String
    , value : Float
    }


providerFromOffer : JustWatchOffer -> JustWatchProvider
providerFromOffer offer =
    case offer of
        Flatrate provider _ _ ->
            provider

        Rent provider _ _ _ ->
            provider

        Buy provider _ _ _ ->
            provider


urlFromOffer : JustWatchOffer -> String
urlFromOffer offer =
    case offer of
        Flatrate _ url _ ->
            url

        Rent _ url _ _ ->
            url

        Buy _ url _ _ ->
            url


type alias JustWatchData =
    { offers : List JustWatchOffer
    , scores : List JustWatchScore
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
            , tableState = Table.initialSort "Priority"
            , buildInfo = BuildInfo flags.build_version flags.build_time flags.build_tier
            }
    in
        ( model
        , getWatchlistData "ur10614064"
        )



-- UPDATE


type Msg
    = LoadWatchList (Result Http.Error (List WatchListMovie))
    | LoadBechdel String (Result Http.Error (Maybe BechdelRating))
    | LoadJustWatch String (Result Http.Error (Maybe JustWatchData))
    | LoadConfirmNetflix String (Result Http.Error (Maybe String))
    | SetTableState Table.State


combine : (a -> b) -> (a -> c) -> (a -> ( b, c ))
combine f g =
    \x -> ( f (x), g (x) )


watchListMovieToMovie : WatchListMovie -> Movie
watchListMovieToMovie watchListMovie =
    { id = watchListMovie.id
    , title = watchListMovie.title
    , imdbUrl = watchListMovie.imdbUrl
    , runTime = watchListMovie.runTime
    , metascore = watchListMovie.metascore
    , rottenTomatoesMeter = Maybe.Nothing
    , imdbRating = watchListMovie.imdbRating
    , bechdelRating = Maybe.Nothing
    , netflixUrl = Maybe.Nothing
    , hboUrl = Maybe.Nothing
    , itunesUrl = Maybe.Nothing
    , amazonUrl = Maybe.Nothing
    }


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
                    Dict.fromList (List.map (combine .id watchListMovieToMovie) watchListMovies)

                bechdelCommands =
                    List.map getBechdelData list

                justWatchCommands =
                    List.map (\movie -> getJustWatchData movie.id movie.title) watchListMovies
            in
                ( { model | list = Maybe.Just list, movies = Dict.union newMovies model.movies }
                  -- We probably eventually want to merge the data here, or simply store it separately
                , Cmd.batch (List.append justWatchCommands bechdelCommands)
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

        LoadJustWatch imdbId (Err error) ->
            ( model
            , Cmd.none
            )

        LoadJustWatch imdbId (Ok justWatchData) ->
            let
                movie =
                    Dict.get imdbId model.movies
            in
                case ( movie, justWatchData ) of
                    ( Maybe.Just movie, Maybe.Just justWatchData ) ->
                        let
                            updatedMovie =
                                { movie
                                    | rottenTomatoesMeter = Maybe.map round (extractScore "tomato:meter" justWatchData.scores)
                                    , netflixUrl = Maybe.map urlFromOffer (extractBestOffer Netflix justWatchData.offers)
                                    , hboUrl = Maybe.map urlFromOffer (extractBestOffer HBO justWatchData.offers)
                                    , amazonUrl = Maybe.map urlFromOffer (extractBestOffer Amazon justWatchData.offers)
                                    , itunesUrl = Maybe.map urlFromOffer (extractBestOffer ITunes justWatchData.offers)
                                }

                            newMovies =
                                Dict.insert imdbId updatedMovie model.movies
                        in
                            ( { model | movies = newMovies }
                            , case updatedMovie.netflixUrl of
                                Maybe.Just netflixUrl ->
                                    getConfirmNetflixData imdbId netflixUrl

                                _ ->
                                    Cmd.none
                            )

                    _ ->
                        ( model
                        , Cmd.none
                        )

        LoadConfirmNetflix imdbId (Err error) ->
            ( model
            , Cmd.none
            )

        LoadConfirmNetflix imdbId (Ok maybeNetflixUrl) ->
            let
                movie =
                    Dict.get imdbId model.movies
            in
                case movie of
                    Maybe.Just movie ->
                        let
                            updatedMovie =
                                { movie
                                    | netflixUrl = maybeNetflixUrl
                                }

                            newMovies =
                                Dict.insert imdbId updatedMovie model.movies
                        in
                            ( { model | movies = newMovies }
                            , Cmd.none
                            )

                    _ ->
                        ( model
                        , Cmd.none
                        )

        SetTableState newState ->
            ( { model | tableState = newState }
            , Cmd.none
            )


offerOrdinal : JustWatchOffer -> ( Int, Int, Float )
offerOrdinal offer =
    let
        presentationTypeOrdinal presentationType =
            case presentationType of
                SD ->
                    0

                HD ->
                    1
    in
        case offer of
            Flatrate _ _ presentationType ->
                ( 2, presentationTypeOrdinal presentationType, 0 )

            Rent _ _ presentationType price ->
                ( 1, presentationTypeOrdinal presentationType, price )

            Buy _ _ presentationType price ->
                ( 0, presentationTypeOrdinal presentationType, price )


offerOrder : JustWatchOffer -> JustWatchOffer -> Order
offerOrder offerA offerB =
    compare (offerOrdinal offerA) (offerOrdinal offerB)


extractBestOffer : JustWatchProvider -> List JustWatchOffer -> Maybe JustWatchOffer
extractBestOffer provider offers =
    List.filter (\o -> (providerFromOffer o) == provider) offers
        |> List.sortWith offerOrder
        |> List.head


extractScore : String -> List JustWatchScore -> Maybe Float
extractScore provider scores =
    List.filter (\s -> s.providerType == provider) scores
        |> List.head
        |> Maybe.map .value



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
        , viewData = \movie -> linkCell movie.title (Maybe.Just movie.imdbUrl)
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
            Maybe.Just url ->
                a [ href url, target "_blank" ] [ text title ]

            Maybe.Nothing ->
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
        Maybe.Just _ ->
            True

        Maybe.Nothing ->
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



-- HTTP


apiUrl : String -> String
apiUrl path =
    "http://localhost:3001" ++ path


getWatchlistData : String -> Cmd Msg
getWatchlistData userId =
    Http.send LoadWatchList <|
        Http.get (apiUrl ("/api/watchlist?userId=" ++ userId)) decodeWatchlist


decodeWatchlist : Decode.Decoder (List WatchListMovie)
decodeWatchlist =
    Decode.at [ "list", "movies" ] (Decode.list decodeWatchlistRowIntoMovie)


decodeWatchlistRowIntoMovie : Decode.Decoder WatchListMovie
decodeWatchlistRowIntoMovie =
    let
        normalizeImdbRating rating =
            round (rating * 10)
    in
        Decode.map6 WatchListMovie
            (Decode.at [ "id" ] Decode.string)
            (Decode.at [ "primary", "title" ] Decode.string)
            decodeImdbUrl
            decodeMovieRunTime
            (Decode.maybe (Decode.at [ "ratings", "metascore" ] Decode.int))
            (Decode.maybe (Decode.map normalizeImdbRating (Decode.at [ "ratings", "rating" ] Decode.float)))


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



-- JUSTWATCH


getJustWatchData : String -> String -> Cmd Msg
getJustWatchData imdbId title =
    Http.send (LoadJustWatch imdbId) <|
        Http.get (apiUrl ("/api/justwatch?imdbId=" ++ imdbId ++ "&title=" ++ title)) decodeJustWatchData


decodeJustWatchData : Decode.Decoder (Maybe JustWatchData)
decodeJustWatchData =
    Decode.maybe
        (Decode.map2 JustWatchData
            (Decode.at [ "data", "offers" ] (Decode.map (List.filterMap identity) (Decode.list decodeOffer)))
            (Decode.at [ "data", "scoring" ] (Decode.list decodeJustWatchScore))
        )


decodeOffer : Decode.Decoder (Maybe JustWatchOffer)
decodeOffer =
    Decode.map5 convertOfferJsonToType
        (Decode.at [ "monetization_type" ] Decode.string)
        (Decode.at [ "provider_id" ] Decode.int)
        (Decode.at [ "urls", "standard_web" ] Decode.string)
        (Decode.at [ "presentation_type" ] Decode.string)
        (Decode.maybe (Decode.at [ "retail_price" ] Decode.float))


convertOfferJsonToType : String -> Int -> String -> String -> Maybe Float -> Maybe JustWatchOffer
convertOfferJsonToType monetizationType providerId url presentationType maybePrice =
    case ( monetizationType, (convertProviderId providerId), (convertPresentationType presentationType), maybePrice ) of
        ( "flatrate", Maybe.Just provider, Maybe.Just presentationType, _ ) ->
            Maybe.Just (Flatrate provider url presentationType)

        ( "buy", Maybe.Just provider, Maybe.Just presentationType, Maybe.Just price ) ->
            Maybe.Just (Buy provider url presentationType price)

        ( "rent", Maybe.Just provider, Maybe.Just presentationType, Maybe.Just price ) ->
            Maybe.Just (Rent provider url presentationType price)

        _ ->
            Maybe.Nothing


convertProviderId : Int -> Maybe JustWatchProvider
convertProviderId providerId =
    case providerId of
        2 ->
            Maybe.Just ITunes

        8 ->
            Maybe.Just Netflix

        10 ->
            Maybe.Just Amazon

        27 ->
            Maybe.Just HBO

        _ ->
            Maybe.Nothing


convertPresentationType : String -> Maybe JustWatchPresentationType
convertPresentationType presentationType =
    case presentationType of
        "hd" ->
            Maybe.Just HD

        "sd" ->
            Maybe.Just SD

        _ ->
            Maybe.Nothing


decodeJustWatchScore : Decode.Decoder JustWatchScore
decodeJustWatchScore =
    Decode.map2 JustWatchScore
        (Decode.field "provider_type" Decode.string)
        (Decode.field "value" Decode.float)



-- NETFLIX


getConfirmNetflixData : String -> String -> Cmd Msg
getConfirmNetflixData imdbId netflixUrl =
    Http.send (LoadConfirmNetflix imdbId) <|
        Http.get (apiUrl ("/api/netflix?locale=is&imdbId=" ++ imdbId ++ "&netflixUrl=" ++ netflixUrl)) decodeConfirmNetflixData


decodeConfirmNetflixData : Decode.Decoder (Maybe String)
decodeConfirmNetflixData =
    Decode.maybe (Decode.at [ "data", "netflixUrl" ] Decode.string)



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
