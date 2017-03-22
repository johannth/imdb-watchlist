module Api exposing (getWatchlistData, subscriptions)

import Json.Decode as Decode
import Http
import Types exposing (..)
import Date exposing (Date)
import Utils exposing (map9)
import Set
import WebSocket
import Json.Encode as Encode


type alias ApiPayload =
    { payloadType : String
    , body : Decode.Value
    }


type alias WatchlistPayload =
    { userId : String
    , movies : List Movie
    }


decodePayload : String -> Result String ApiPayload
decodePayload encodedPayload =
    let
        basePayloadDecoder =
            Decode.map2 ApiPayload
                (Decode.field "type" Decode.string)
                (Decode.field "body" Decode.value)
    in
        Decode.decodeString basePayloadDecoder encodedPayload


decodeWatchlistPayload : Decode.Decoder WatchlistPayload
decodeWatchlistPayload =
    Decode.map2 WatchlistPayload
        (Decode.field "userId" Decode.string)
        decodeWatchlist


handlePayload : String -> Msg
handlePayload encodedPayload =
    case decodePayload encodedPayload of
        Ok payload ->
            case payload.payloadType of
                "watchlist" ->
                    case Decode.decodeValue decodeWatchlistPayload payload.body of
                        Ok payload ->
                            ReceivedWatchList payload.userId payload.movies

                        _ ->
                            Void

                _ ->
                    Void

        Err error ->
            Void


subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen (websocketsUrl model.apiHost) handlePayload


apiUrl : String -> String -> String
apiUrl apiHost path =
    apiHost ++ path


websocketsUrl : String -> String
websocketsUrl apiHost =
    "ws://" ++ apiHost ++ "/stream"


websocketRequest : String -> String -> List ( String, Encode.Value ) -> Cmd Msg
websocketRequest apiHost messageType messageBody =
    let
        encodedMessageBody =
            Encode.object [ ( "type", Encode.string messageType ), ( "body", Encode.object messageBody ) ]
    in
        WebSocket.send (websocketsUrl apiHost) (Encode.encode 0 encodedMessageBody)


getWatchlistData : String -> String -> Cmd Msg
getWatchlistData apiHost imdbUserId =
    websocketRequest apiHost "watchlist" [ ( "userId", Encode.string imdbUserId ) ]


decodeWatchlist : Decode.Decoder (List Movie)
decodeWatchlist =
    Decode.at [ "list", "movies" ] (Decode.list decodeMovie)


decodeMovie : Decode.Decoder Movie
decodeMovie =
    map9 Movie
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "imdbUrl" Decode.string)
        decodeItemType
        decodeMovieReleaseDate
        (Decode.maybe (Decode.field "runTime" Decode.int))
        (Decode.field "genres" (Decode.map Set.fromList (Decode.list Decode.string)))
        (Decode.field "ratings" decodeRatings)
        (Decode.succeed (ViewingOptions Nothing Nothing Nothing Nothing))


decodeItemType : Decode.Decoder MovieType
decodeItemType =
    Decode.map
        (\value ->
            case value of
                "featureFilm" ->
                    Film

                "series" ->
                    Series

                _ ->
                    Film
        )
        (Decode.at [ "type" ] Decode.string)


decodeMovieReleaseDate : Decode.Decoder (Maybe Date)
decodeMovieReleaseDate =
    Decode.maybe (Decode.map Date.fromTime (Decode.field "releaseDate" Decode.float))


decodeRatings : Decode.Decoder Ratings
decodeRatings =
    Decode.map4 Ratings
        (Decode.maybe (Decode.field "metascore" Decode.int))
        (Decode.maybe (Decode.field "rottenTomatoesMeter" Decode.int))
        (Decode.maybe (Decode.field "imdbRating" Decode.int))
        (Decode.succeed Nothing)



--
-- -- BECHDEL
--
--
-- getBechdelData : String -> String -> Cmd Msg
-- getBechdelData apiHost imdbId =
--     Http.send (LoadBechdel imdbId) <|
--         Http.get (apiUrl apiHost ("/api/bechdel?imdbId=" ++ imdbId)) decodeBechdel
--
--
-- decodeBechdel : Decode.Decoder (Maybe BechdelRating)
-- decodeBechdel =
--     Decode.maybe
--         (Decode.map2 BechdelRating
--             (Decode.at [ "data", "rating" ] (Decode.string |> Decode.andThen decodeIntFromString))
--             (Decode.at [ "data", "dubious" ] (Decode.string |> Decode.andThen decodeBoolFromInt))
--         )
--
--
-- decodeIntFromString : String -> Decode.Decoder Int
-- decodeIntFromString value =
--     case String.toInt value of
--         Ok valueAsInt ->
--             Decode.succeed valueAsInt
--
--         Err message ->
--             Decode.fail message
--
--
-- decodeBoolFromInt : String -> Decode.Decoder Bool
-- decodeBoolFromInt value =
--     case value of
--         "0" ->
--             Decode.succeed False
--
--         "1" ->
--             Decode.succeed True
--
--         _ ->
--             Decode.fail ("Unable to decode Bool from value: " ++ (toString value))
--
--
--
-- -- JUSTWATCH
--
--
-- getJustWatchData : String -> String -> String -> MovieType -> Maybe Int -> Cmd Msg
-- getJustWatchData apiHost imdbId title itemType year =
--     let
--         yearPart =
--             Maybe.withDefault "" (Maybe.map (\year -> "&year=" ++ toString year) year)
--
--         typePart =
--             "&type="
--                 ++ (case itemType of
--                         Film ->
--                             "film"
--
--                         Series ->
--                             "series"
--                    )
--
--         query =
--             "imdbId=" ++ imdbId ++ "&title=" ++ title ++ yearPart ++ typePart
--     in
--         Http.send (LoadJustWatch imdbId) <|
--             Http.get (apiUrl apiHost ("/api/justwatch?" ++ query)) decodeJustWatchData
--
--
-- decodeJustWatchData : Decode.Decoder (Maybe JustWatchData)
-- decodeJustWatchData =
--     Decode.maybe
--         (Decode.map2 JustWatchData
--             (Decode.at [ "data", "offers" ] (Decode.map (List.filterMap identity) (Decode.list decodeOffer)))
--             (Decode.at [ "data", "scoring" ] (Decode.list decodeJustWatchScore))
--         )
--
--
-- decodeOffer : Decode.Decoder (Maybe JustWatchOffer)
-- decodeOffer =
--     Decode.map5 convertOfferJsonToType
--         (Decode.at [ "monetization_type" ] Decode.string)
--         (Decode.at [ "provider_id" ] Decode.int)
--         (Decode.at [ "urls", "standard_web" ] Decode.string)
--         (Decode.at [ "presentation_type" ] Decode.string)
--         (Decode.maybe (Decode.at [ "retail_price" ] Decode.float))
--
--
-- convertOfferJsonToType : String -> Int -> String -> String -> Maybe Float -> Maybe JustWatchOffer
-- convertOfferJsonToType monetizationType providerId url presentationType maybePrice =
--     case ( monetizationType, (convertProviderId providerId), (convertPresentationType presentationType), maybePrice ) of
--         ( "flatrate", Maybe.Just provider, Maybe.Just presentationType, _ ) ->
--             Maybe.Just (Flatrate provider url presentationType)
--
--         ( "buy", Maybe.Just provider, Maybe.Just presentationType, Maybe.Just price ) ->
--             Maybe.Just (Buy provider url presentationType price)
--
--         ( "rent", Maybe.Just provider, Maybe.Just presentationType, Maybe.Just price ) ->
--             Maybe.Just (Rent provider url presentationType price)
--
--         _ ->
--             Maybe.Nothing
--
--
-- convertProviderId : Int -> Maybe JustWatchProvider
-- convertProviderId providerId =
--     case providerId of
--         2 ->
--             Maybe.Just ITunes
--
--         8 ->
--             Maybe.Just Netflix
--
--         10 ->
--             Maybe.Just Amazon
--
--         27 ->
--             Maybe.Just HBO
--
--         _ ->
--             Maybe.Nothing
--
--
-- convertPresentationType : String -> Maybe JustWatchPresentationType
-- convertPresentationType presentationType =
--     case presentationType of
--         "hd" ->
--             Maybe.Just HD
--
--         "sd" ->
--             Maybe.Just SD
--
--         _ ->
--             Maybe.Nothing
--
--
-- decodeJustWatchScore : Decode.Decoder JustWatchScore
-- decodeJustWatchScore =
--     Decode.map2 JustWatchScore
--         (Decode.field "provider_type" Decode.string)
--         (Decode.field "value" Decode.float)
--
--
--
-- -- NETFLIX
--
--
-- getConfirmNetflixData : String -> String -> String -> Maybe Int -> Maybe String -> Cmd Msg
-- getConfirmNetflixData apiHost imdbId title year netflixUrl =
--     let
--         yearPart =
--             Maybe.withDefault "" (Maybe.map (\year -> "&year=" ++ (toString year)) year)
--
--         netflixUrlPart =
--             Maybe.withDefault "" (Maybe.map (\netflixUrl -> "&netflixUrl=" ++ netflixUrl) netflixUrl)
--     in
--         Http.send (LoadConfirmNetflix imdbId) <|
--             Http.get (apiUrl apiHost ("/api/netflix?locale=is&imdbId=" ++ imdbId ++ "&title=" ++ title ++ yearPart ++ netflixUrlPart)) decodeConfirmNetflixData
--
--
-- decodeConfirmNetflixData : Decode.Decoder (Maybe String)
-- decodeConfirmNetflixData =
--     Decode.maybe (Decode.at [ "data", "netflixUrl" ] Decode.string)
