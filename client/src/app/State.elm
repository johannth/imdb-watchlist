module State exposing (init, update, calculatePriority)

import Dict
import Api
import Types exposing (..)


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( emptyModel flags
    , Api.getWatchlistData "ur10614064"
    )


lift2 : (a -> b) -> (a -> c) -> (a -> ( b, c ))
lift2 f g =
    \x -> ( f x, g x )


maybeHasValue : Maybe a -> Bool
maybeHasValue maybeValue =
    case maybeValue of
        Just _ ->
            True

        Nothing ->
            False


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadWatchList (Err error) ->
            model ! []

        LoadWatchList (Ok watchListMovies) ->
            let
                listOfIds =
                    List.map .id watchListMovies

                newMovies =
                    List.map (lift2 .id watchListMovieToMovie) watchListMovies
                        |> Dict.fromList

                bechdelCommands =
                    List.map Api.getBechdelData listOfIds

                justWatchCommands =
                    List.map (\movie -> Api.getJustWatchData movie.id movie.title) watchListMovies
            in
                { model
                    | list = Just listOfIds
                    , movies = Dict.union newMovies model.movies
                }
                    ! (justWatchCommands ++ bechdelCommands)

        LoadBechdel imdbId (Err error) ->
            model ! []

        LoadBechdel imdbId (Ok bechdelRating) ->
            case Dict.get imdbId model.movies of
                Just movie ->
                    let
                        updatedMovie =
                            { movie | bechdelRating = bechdelRating }
                    in
                        { model | movies = Dict.insert imdbId updatedMovie model.movies } ! []

                Nothing ->
                    model ! []

        LoadJustWatch imdbId (Err error) ->
            model ! []

        LoadJustWatch imdbId (Ok justWatchData) ->
            case ( Dict.get imdbId model.movies, justWatchData ) of
                ( Just movie, Just justWatchData ) ->
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
                        { model | movies = newMovies }
                            ! case updatedMovie.netflixUrl of
                                Just netflixUrl ->
                                    [ Api.getConfirmNetflixData imdbId netflixUrl ]

                                Nothing ->
                                    []

                _ ->
                    model ! []

        LoadConfirmNetflix imdbId (Err error) ->
            model ! []

        LoadConfirmNetflix imdbId (Ok maybeNetflixUrl) ->
            case Dict.get imdbId model.movies of
                Just movie ->
                    let
                        updatedMovie =
                            { movie | netflixUrl = maybeNetflixUrl }
                    in
                        { model | movies = Dict.insert imdbId updatedMovie model.movies } ! []

                Nothing ->
                    model ! []

        SetTableState newState ->
            { model | tableState = newState } ! []


extractBestOffer : JustWatchProvider -> List JustWatchOffer -> Maybe JustWatchOffer
extractBestOffer provider offers =
    List.filter (\offer -> (providerFromOffer offer) == provider) offers
        |> List.sortWith offerOrder
        |> List.head


offerOrder : JustWatchOffer -> JustWatchOffer -> Order
offerOrder offerA offerB =
    compare (offerOrdinal offerA) (offerOrdinal offerB)


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


extractScore : String -> List JustWatchScore -> Maybe Float
extractScore provider scores =
    List.filter (\score -> score.providerType == provider) scores
        |> List.head
        |> Maybe.map .value


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
