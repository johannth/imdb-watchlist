module State exposing (init, update, calculatePriority)

import Dict
import Api
import Types exposing (..)
import Utils
import Navigation
import UrlParser exposing ((<?>))


init : Flags -> Navigation.Location -> ( Model, Cmd Msg )
init flags location =
    let
        imdbUserIdsFromPath =
            parseImdbUserIdsFromPath location

        initialModel =
            emptyModel flags

        initalLists =
            Dict.fromList (List.map (Utils.lift2 identity (always [])) imdbUserIdsFromPath)
    in
        { initialModel | lists = initalLists } ! List.map Api.getWatchlistData imdbUserIdsFromPath


parseImdbUserIdsFromPath : Navigation.Location -> List String
parseImdbUserIdsFromPath location =
    UrlParser.parsePath (UrlParser.s "" <?> UrlParser.stringParam "imdbUserIds") location
        |> Maybe.andThen identity
        |> Maybe.map (String.split ",")
        |> Maybe.withDefault []


updatedUrl : Model -> String
updatedUrl model =
    "?imdbUserIds=" ++ (String.join "," (Dict.keys model.lists))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ImdbUserIdInput partialImdbUserId ->
            { model | imdbUserIdInputCurrentValue = partialImdbUserId } ! []

        LookupWatchList imdbUserId ->
            let
                newModel =
                    { model
                        | imdbUserIdInputCurrentValue = ""
                        , lists = Dict.insert imdbUserId [] model.lists
                    }
            in
                newModel
                    ! [ Api.getWatchlistData imdbUserId, Navigation.modifyUrl (updatedUrl newModel) ]

        ClearList imdbUserId ->
            let
                newModel =
                    { model | lists = Dict.remove imdbUserId model.lists }
            in
                newModel ! [ Navigation.modifyUrl (updatedUrl newModel) ]

        LoadWatchList imdbUserId (Err error) ->
            model ! []

        LoadWatchList imdbUserId (Ok watchListMovies) ->
            let
                listOfIds =
                    List.map .id watchListMovies

                newMovies =
                    List.map (Utils.lift2 .id watchListMovieToMovie) watchListMovies
                        |> Dict.fromList

                bechdelCommands =
                    List.map Api.getBechdelData listOfIds

                justWatchCommands =
                    List.map (\movie -> Api.getJustWatchData movie.id movie.title) watchListMovies
            in
                { model
                    | lists = Dict.insert imdbUserId listOfIds model.lists
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
                                , netflix = extractBestOffer Netflix justWatchData.offers
                                , hbo = extractBestOffer HBO justWatchData.offers
                                , amazon = extractBestOffer Amazon justWatchData.offers
                                , itunes = extractBestOffer ITunes justWatchData.offers
                            }

                        newMovies =
                            Dict.insert imdbId updatedMovie model.movies
                    in
                        { model | movies = newMovies }
                            ! case updatedMovie.netflix of
                                Just netflixOffer ->
                                    [ Api.getConfirmNetflixData imdbId (urlFromOffer netflixOffer) ]

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
                            { movie
                                | netflix =
                                    case maybeNetflixUrl of
                                        Just netflixUrl ->
                                            Maybe.map (updateUrl netflixUrl) movie.netflix

                                        Nothing ->
                                            Maybe.Nothing
                            }
                    in
                        { model | movies = Dict.insert imdbId updatedMovie model.movies } ! []

                Nothing ->
                    model ! []

        SetTableState newState ->
            { model | tableState = newState } ! []

        UrlChange newLocation ->
            model ! []


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
                    1

                HD ->
                    0
    in
        case offer of
            Flatrate _ _ presentationType ->
                ( 0, presentationTypeOrdinal presentationType, 0 )

            Rent _ _ presentationType price ->
                ( 1, presentationTypeOrdinal presentationType, price )

            Buy _ _ presentationType price ->
                ( 2, presentationTypeOrdinal presentationType, price )


extractScore : String -> List JustWatchScore -> Maybe Float
extractScore provider scores =
    List.filter (\score -> score.providerType == provider) scores
        |> List.head
        |> Maybe.map .value


calculateStreamabilityWeight : Movie -> Float
calculateStreamabilityWeight movie =
    if List.any Utils.maybeHasValue [ movie.netflix, movie.hbo ] then
        1
    else if List.any Utils.maybeHasValue [ movie.itunes, movie.amazon ] then
        0.6
    else
        0.1


toInt : Bool -> Int
toInt bool =
    case bool of
        True ->
            1

        False ->
            0


normalizeBechdel : BechdelRating -> Int
normalizeBechdel bechdel =
    round ((toFloat bechdel.rating - 0.5 * (toFloat (toInt bechdel.dubious))) / 3.0 * 100)


runTimeRatingFormula : Float -> Float -> Float -> Float
runTimeRatingFormula optimalRunTime optimalRunTimeScore runTime =
    let
        k =
            (optimalRunTime * optimalRunTimeScore) / (1 - optimalRunTimeScore)
    in
        k / (runTime + k) * 100


calculatePriority : Movie -> Float
calculatePriority movie =
    let
        extractValueToFloat default maybeInt =
            Maybe.withDefault default (Maybe.map toFloat maybeInt)

        streamabilityWeight =
            calculateStreamabilityWeight movie

        runTimeWeight =
            1 / 5

        normalizedRunTime =
            runTimeRatingFormula 90 0.5 (extractValueToFloat 90 movie.runTime)

        metascoreWeight =
            1 / 5

        tomatoMeterWeight =
            1 / 5

        imdbRatingWeight =
            1 / 5

        bechdelWeight =
            1 / 5

        normalizedBechdel =
            extractValueToFloat 50 (Maybe.map normalizeBechdel movie.bechdelRating)
    in
        streamabilityWeight
            * (metascoreWeight
                * (extractValueToFloat 50 movie.metascore)
                + tomatoMeterWeight
                * (extractValueToFloat 50 movie.rottenTomatoesMeter)
                + imdbRatingWeight
                * (extractValueToFloat 50 movie.imdbRating)
                + bechdelWeight
                * normalizedBechdel
                + runTimeWeight
                * normalizedRunTime
              )
