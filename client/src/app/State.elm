module State exposing (init, update)

import Dict
import Types exposing (..)
import Api


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( emptyModel flags
    , Api.getWatchlistData "ur10614064"
    )


combine : (a -> b) -> (a -> c) -> (a -> ( b, c ))
combine f g =
    \x -> ( f (x), g (x) )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoadWatchList (Err error) ->
            model ! []

        LoadWatchList (Ok watchListMovies) ->
            let
                list =
                    List.map .id watchListMovies

                newMovies =
                    Dict.fromList (List.map (combine .id watchListMovieToMovie) watchListMovies)

                bechdelCommands =
                    List.map Api.getBechdelData list

                justWatchCommands =
                    List.map (\movie -> Api.getJustWatchData movie.id movie.title) watchListMovies
            in
                { model | list = Maybe.Just list, movies = Dict.union newMovies model.movies }
                    ! (List.append justWatchCommands bechdelCommands)

        LoadBechdel imdbId (Err error) ->
            model ! []

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
                            { model | movies = newMovies } ! []

                    Maybe.Nothing ->
                        model ! []

        LoadJustWatch imdbId (Err error) ->
            model ! []

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
                            { model | movies = newMovies }
                                ! case updatedMovie.netflixUrl of
                                    Maybe.Just netflixUrl ->
                                        [ Api.getConfirmNetflixData imdbId netflixUrl ]

                                    _ ->
                                        []

                    _ ->
                        model ! []

        LoadConfirmNetflix imdbId (Err error) ->
            model ! []

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
                            { model | movies = newMovies } ! []

                    _ ->
                        model ! []

        SetTableState newState ->
            { model | tableState = newState } ! []


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
