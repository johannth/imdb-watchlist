module Api exposing (getWatchlistData, getBatchDetailedMovieData, subscriptions)

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

                        Err error ->
                            Error error

                "movies" ->
                    case Decode.decodeValue (Decode.field "movies" (Decode.list decodeMovie)) payload.body of
                        Ok movies ->
                            ReceivedMovies movies

                        Err error ->
                            Error error

                _ ->
                    Void

        Err error ->
            Error error


subscriptions : Model -> Sub Msg
subscriptions model =
    WebSocket.listen (websocketsUrl model.apiHost) handlePayload


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


getDetailedMovieData : String -> Movie -> Cmd Msg
getDetailedMovieData apiHost movie =
    websocketRequest apiHost "movie" [ ( "movie", encodeMovie movie ) ]


getBatchDetailedMovieData : String -> List Movie -> Cmd Msg
getBatchDetailedMovieData apiHost movies =
    websocketRequest apiHost "movies" [ ( "movies", Encode.list (List.map encodeMovie movies) ) ]


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
        (Decode.field "viewingOptions" decodeViewingOptions)


encodeMovie : Movie -> Encode.Value
encodeMovie movie =
    Encode.object
        [ ( "id", Encode.string movie.id )
        , ( "title", Encode.string movie.title )
        , ( "imdbUrl", Encode.string movie.imdbUrl )
        , ( "type", encodeMovieType movie.itemType )
        , ( "releaseDate"
          , case movie.releaseDate of
                Just releaseDate ->
                    Encode.float (Date.toTime releaseDate)

                Nothing ->
                    Encode.null
          )
        , ( "runTime"
          , case movie.runTime of
                Just runTime ->
                    Encode.int runTime

                Nothing ->
                    Encode.null
          )
        , ( "genres", Encode.list (List.map Encode.string (Set.toList movie.genres)) )
        , ( "ratings", encodeRatings movie.ratings )
        , ( "viewingOptions", Encode.null )
          -- TODO
        ]


encodeRatings : Ratings -> Encode.Value
encodeRatings ratings =
    let
        encodeMaybeInt =
            Maybe.map Encode.int >> Maybe.withDefault Encode.null
    in
        Encode.object
            [ ( "imdb", encodeMaybeInt ratings.imdb )
            , ( "metascore", encodeMaybeInt ratings.metascore )
            , ( "rottenTomatoesMeter", encodeMaybeInt ratings.rottenTomatoesMeter )
            ]


decodeItemType : Decode.Decoder MovieType
decodeItemType =
    Decode.map
        (\value ->
            case value of
                "file" ->
                    Film

                "series" ->
                    Series

                _ ->
                    Film
        )
        (Decode.at [ "type" ] Decode.string)


encodeMovieType : MovieType -> Encode.Value
encodeMovieType movieType =
    Encode.string
        (case movieType of
            Film ->
                "film"

            Series ->
                "series"
        )


decodeMovieReleaseDate : Decode.Decoder (Maybe Date)
decodeMovieReleaseDate =
    Decode.maybe (Decode.map Date.fromTime (Decode.field "releaseDate" Decode.float))


decodeRatings : Decode.Decoder Ratings
decodeRatings =
    Decode.map4 Ratings
        (Decode.maybe (Decode.field "metascore" Decode.int))
        (Decode.maybe (Decode.field "rottenTomatoesMeter" Decode.int))
        (Decode.maybe (Decode.field "imdb" Decode.int))
        (Decode.maybe (Decode.field "bechdel" decodeBechdel))


decodeBechdel : Decode.Decoder BechdelRating
decodeBechdel =
    (Decode.map2 BechdelRating
        (Decode.field "rating" Decode.int)
        (Decode.field "dubious" Decode.bool)
    )


encodeBechdel : BechdelRating -> Encode.Value
encodeBechdel bechdelRating =
    Encode.object
        [ ( "rating", Encode.int bechdelRating.rating )
        , ( "dubious", Encode.bool bechdelRating.dubious )
        ]


decodeViewingOptions : Decode.Decoder ViewingOptions
decodeViewingOptions =
    Decode.map4 ViewingOptions
        (unwrapDecoder (Decode.maybe (Decode.field "netflix" decodeViewingOption)))
        (unwrapDecoder (Decode.maybe (Decode.field "hbo" decodeViewingOption)))
        (unwrapDecoder (Decode.maybe (Decode.field "itunes" decodeViewingOption)))
        (unwrapDecoder (Decode.maybe (Decode.field "amazon" decodeViewingOption)))


unwrapDecoder : Decode.Decoder (Maybe (Maybe a)) -> Decode.Decoder (Maybe a)
unwrapDecoder decoder =
    decoder
        |> Decode.andThen
            (\maybeValue ->
                case maybeValue of
                    Just value ->
                        Decode.succeed value

                    Nothing ->
                        Decode.succeed Nothing
            )


decodeViewingOption : Decode.Decoder (Maybe ViewingOption)
decodeViewingOption =
    Decode.map5 convertViewingOptionJsonToType
        (Decode.field "monetizationType" Decode.string)
        (Decode.field "provider" Decode.string)
        (Decode.field "url" Decode.string)
        (Decode.field "presentationType" Decode.string)
        (Decode.maybe (Decode.field "price" Decode.float))


convertViewingOptionJsonToType : String -> String -> String -> String -> Maybe Float -> Maybe ViewingOption
convertViewingOptionJsonToType monetizationType providerId url presentationType maybePrice =
    case ( monetizationType, (convertProviderId providerId), (convertPresentationType presentationType), maybePrice ) of
        ( "flatrate", Just provider, Just presentationType, _ ) ->
            Just (Flatrate provider url presentationType)

        ( "buy", Just provider, Just presentationType, Just price ) ->
            Just (Buy provider url presentationType price)

        ( "rent", Just provider, Just presentationType, Just price ) ->
            Just (Rent provider url presentationType price)

        _ ->
            Nothing


convertProviderId : String -> Maybe ViewingOptionProvider
convertProviderId providerString =
    case providerString of
        "itunes" ->
            Just ITunes

        "netflix" ->
            Just Netflix

        "amazon" ->
            Just Amazon

        "hbo" ->
            Just HBO

        _ ->
            Nothing


convertPresentationType : String -> Maybe ViewingOptionPresentationType
convertPresentationType presentationType =
    case presentationType of
        "hd" ->
            Just HD

        "sd" ->
            Just SD

        _ ->
            Nothing



-- decodeJustWatchScore : Decode.Decoder JustWatchScore
-- decodeJustWatchScore =
--     Decode.map2 JustWatchScore
--         (Decode.field "provider_type" Decode.string)
--         (Decode.field "value" Decode.float)
--
--
--
