module State exposing (init, update, calculatePriority, calculatePriorityWithWeights, defaultPriorityWeights, normalizeBechdel, normalizeRunTime)

import Dict
import Api
import Types exposing (..)
import Utils
import Navigation
import UrlParser exposing ((<?>))
import Set


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
        { initialModel | lists = initalLists } ! List.map (Api.getWatchlistData initialModel.apiHost) imdbUserIdsFromPath


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
                    ! [ Api.getWatchlistData model.apiHost imdbUserId, Navigation.modifyUrl (updatedUrl newModel) ]

        ClearList imdbUserId ->
            let
                newModel =
                    { model | lists = Dict.remove imdbUserId model.lists }
            in
                newModel ! [ Navigation.modifyUrl (updatedUrl newModel) ]

        ReceivedWatchList imdbUserId (Err error) ->
            let
                message =
                    Debug.log "Error" error
            in
                model ! []

        ReceivedWatchList imdbUserId (Ok movies) ->
            let
                listOfIds =
                    List.map .id movies

                newMovies =
                    List.map (Utils.lift2 .id identity) movies
                        |> Dict.fromList

                newGenres =
                    List.foldl Set.union Set.empty (List.map .genres (Dict.values newMovies))

                batchesOfMovies =
                    Utils.batches 40 (Dict.values newMovies)
            in
                { model
                    | lists = Dict.insert imdbUserId listOfIds model.lists
                    , movies = Dict.union newMovies model.movies
                    , genres = Set.union newGenres model.genres
                }
                    ! List.map (Api.getBatchDetailedMovieData model.apiHost) batchesOfMovies

        ReceivedMovies (Err error) ->
            let
                message =
                    Debug.log "Error" error
            in
                model ! []

        ReceivedMovies (Ok movies) ->
            let
                newMovies =
                    List.map (Utils.lift2 .id identity) movies
                        |> Dict.fromList
            in
                { model | movies = Dict.union newMovies model.movies } ! []

        Error error ->
            { model | error = Just error } ! []

        SetTableState newState ->
            { model | tableState = newState } ! []

        UrlChange newLocation ->
            model ! []

        ToggleGenreFilter genre ->
            (if Set.member genre model.selectedGenres then
                { model | selectedGenres = Set.remove genre model.selectedGenres }
             else
                { model | selectedGenres = Set.insert genre model.selectedGenres }
            )
                ! []


calculateStreamabilityWeight : Movie -> Float
calculateStreamabilityWeight movie =
    if List.any Utils.maybeHasValue [ movie.viewingOptions.netflix, movie.viewingOptions.hbo, movie.viewingOptions.showtime ] then
        1
    else if List.any Utils.maybeHasValue [ movie.viewingOptions.itunes, movie.viewingOptions.amazon ] then
        0.7
    else
        0.1


normalizeBechdel : BechdelRating -> Int
normalizeBechdel bechdel =
    let
        toInt : Bool -> Int
        toInt bool =
            case bool of
                True ->
                    1

                False ->
                    0

        ratingAdjustedForDubious =
            max 0 (toFloat bechdel.rating - 0.5 * (toFloat << toInt) bechdel.dubious)
    in
        round (ratingAdjustedForDubious / 3.0 * 100)


normalizeRunTime : Float -> Float
normalizeRunTime =
    normalizeRunTimeWithParameters 120 0.5


normalizeRunTimeWithParameters : Float -> Float -> Float -> Float
normalizeRunTimeWithParameters optimalRunTime optimalRunTimeScore runTime =
    let
        k =
            (optimalRunTime ^ 2 * optimalRunTimeScore) / (1 - optimalRunTimeScore)
    in
        k / (runTime ^ 2 + k) * 100


calculatePriority : Int -> Movie -> Float
calculatePriority nrOfVotes =
    calculatePriorityWithWeights nrOfVotes defaultPriorityWeights


calculateAverage : List (Maybe Int) -> Float
calculateAverage list =
    let
        values =
            List.filterMap identity list

        numberOfValues =
            List.length values
    in
        if numberOfValues == 0 then
            50
        else
            (toFloat (List.sum values)) / (toFloat numberOfValues)


calculatePriorityWithWeights : Int -> PriorityWeights -> Movie -> Float
calculatePriorityWithWeights nrOfVotes weights movie =
    let
        extractValueToFloat default maybeInt =
            Maybe.withDefault default (Maybe.map toFloat maybeInt)

        streamabilityWeight =
            calculateStreamabilityWeight movie

        runTime =
            (extractValueToFloat 90 movie.runTime)

        normalizedRunTime =
            normalizeRunTime runTime

        normalizedTotalRunTime =
            normalizeRunTime (runTime * (toFloat movie.numberOfEpisodes))

        normalizedBechdel =
            extractValueToFloat 50 (Maybe.map normalizeBechdel movie.ratings.bechdel)

        defaultRatingIfMissing =
            calculateAverage [ movie.ratings.metascore, movie.ratings.rottenTomatoesMeter, movie.ratings.imdb ]

        nrOfVotesWeight =
            toFloat nrOfVotes
    in
        nrOfVotesWeight
            * streamabilityWeight
            * (weights.metascore
                * (extractValueToFloat defaultRatingIfMissing movie.ratings.metascore)
                + weights.tomatoMeter
                * (extractValueToFloat defaultRatingIfMissing movie.ratings.rottenTomatoesMeter)
                + weights.imdbRating
                * (extractValueToFloat defaultRatingIfMissing movie.ratings.imdb)
                + weights.bechdel
                * normalizedBechdel
                + weights.runTime
                * (0.7 * normalizedRunTime + 0.3 * normalizedTotalRunTime)
              )


defaultPriorityWeights : PriorityWeights
defaultPriorityWeights =
    let
        runTimeWeight =
            2 / 9

        ratingWeight =
            5 / 9

        bechdelWeight =
            2 / 9
    in
        { runTime = runTimeWeight
        , metascore = ratingWeight * 3 / 6
        , tomatoMeter = ratingWeight * 2 / 6
        , imdbRating = ratingWeight * 1 / 6
        , bechdel = bechdelWeight
        }
