module Api exposing (getWatchlistData, getBatchDetailedMovieData)

import Json.Decode as Decode
import Http
import Types exposing (..)
import Date exposing (Date)
import Utils exposing (map10)
import Set
import Json.Encode as Encode


apiUrl : String -> String -> String
apiUrl apiHost path =
    "http://" ++ apiHost ++ path


getWatchlistData : String -> String -> Cmd Msg
getWatchlistData apiHost imdbUserId =
    Http.send (ReceivedWatchList imdbUserId) <|
        Http.get (apiUrl apiHost ("/api/watchlist?userId=" ++ imdbUserId)) (Decode.at [ "list", "movies" ] (Decode.list decodeMovie))


getBatchDetailedMovieData : String -> List Movie -> Cmd Msg
getBatchDetailedMovieData apiHost movies =
    let
        body =
            (Encode.object [ ( "movies", Encode.list (List.map encodeMovie movies) ) ])
    in
        Http.send ReceivedMovies <|
            Http.post (apiUrl apiHost "/api/movies") (Http.jsonBody body) (Decode.field "movies" (Decode.list decodeMovie))


decodeMovie : Decode.Decoder Movie
decodeMovie =
    map10 Movie
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "imdbUrl" Decode.string)
        decodeItemType
        decodeMovieReleaseDate
        (Decode.maybe (Decode.field "runTime" Decode.int))
        (Decode.field "numberOfEpisodes" Decode.int)
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
        , ( "numberOfEpisodes", Encode.int movie.numberOfEpisodes )
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
