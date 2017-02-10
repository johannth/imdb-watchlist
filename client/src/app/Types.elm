module Types exposing (..)

import Table
import Dict
import Http


type alias Model =
    { list : Maybe (List String)
    , movies : Dict.Dict String Movie
    , buildInfo : BuildInfo
    , tableState : Table.State
    }


type Msg
    = LoadWatchList (Result Http.Error (List WatchListMovie))
    | LoadBechdel String (Result Http.Error (Maybe BechdelRating))
    | LoadJustWatch String (Result Http.Error (Maybe JustWatchData))
    | LoadConfirmNetflix String (Result Http.Error (Maybe String))
    | SetTableState Table.State


emptyModel : Flags -> Model
emptyModel flags =
    { list = Maybe.Nothing
    , movies = Dict.empty
    , tableState = Table.initialSort "Priority"
    , buildInfo = BuildInfo flags.build_version flags.build_time flags.build_tier
    }


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



-- BUILD INFO


type alias Flags =
    { build_version : String
    , build_tier : String
    , build_time : String
    }


type alias BuildInfo =
    { version : String
    , time : String
    , tier : String
    }



-- JUST WATCH


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



-- BECHDEL


type alias BechdelRating =
    { rating : Int
    , dubious : Bool
    }
