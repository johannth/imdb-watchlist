module Api exposing (getWatchlistData, getBechdelData, getJustWatchData, getConfirmNetflixData)

import Json.Decode as Decode
import Http
import Types exposing (..)


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
