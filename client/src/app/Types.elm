module Types exposing (..)

import Table
import Dict
import Http
import Navigation
import Date exposing (Date)


type alias Model =
    { apiHost : String
    , imdbUserIdInputCurrentValue : String
    , lists : Dict.Dict String (List String)
    , movies : Dict.Dict String Movie
    , buildInfo : BuildInfo
    , tableState : Table.State
    }


type Msg
    = LookupWatchList String
    | ImdbUserIdInput String
    | LoadWatchList String (Result Http.Error (List WatchListMovie))
    | ClearList String
    | LoadBechdel String (Result Http.Error (Maybe BechdelRating))
    | LoadJustWatch String (Result Http.Error (Maybe JustWatchData))
    | LoadConfirmNetflix String (Result Http.Error (Maybe String))
    | SetTableState Table.State
    | UrlChange Navigation.Location


emptyModel : Flags -> Model
emptyModel flags =
    { apiHost = flags.apiHost
    , imdbUserIdInputCurrentValue = ""
    , lists = Dict.empty
    , movies = Dict.empty
    , tableState = Table.initialSort "Priority"
    , buildInfo = BuildInfo flags.buildVersion flags.buildTime flags.buildTier
    }


type alias WatchListMovie =
    { id : String
    , title : String
    , imdbUrl : String
    , releaseDate : Maybe Date
    , runTime : Maybe Int
    , metascore : Maybe Int
    , imdbRating : Maybe Int
    }


type alias Movie =
    { id : String
    , title : String
    , imdbUrl : String
    , releaseDate : Maybe Date
    , runTime : Maybe Int
    , metascore : Maybe Int
    , rottenTomatoesMeter : Maybe Int
    , imdbRating : Maybe Int
    , bechdelRating : Maybe BechdelRating
    , netflix : Maybe JustWatchOffer
    , hbo : Maybe JustWatchOffer
    , itunes : Maybe JustWatchOffer
    , amazon : Maybe JustWatchOffer
    }


watchListMovieToMovie : WatchListMovie -> Movie
watchListMovieToMovie watchListMovie =
    { id = watchListMovie.id
    , title = watchListMovie.title
    , imdbUrl = watchListMovie.imdbUrl
    , releaseDate = watchListMovie.releaseDate
    , runTime = watchListMovie.runTime
    , metascore = watchListMovie.metascore
    , rottenTomatoesMeter = Maybe.Nothing
    , imdbRating = watchListMovie.imdbRating
    , bechdelRating = Maybe.Nothing
    , netflix = Maybe.Nothing
    , hbo = Maybe.Nothing
    , itunes = Maybe.Nothing
    , amazon = Maybe.Nothing
    }


type alias PriorityWeights =
    { runTime : Float
    , metascore : Float
    , tomatoMeter : Float
    , imdbRating : Float
    , bechdel : Float
    }



-- BUILD INFO


type alias Flags =
    { apiHost : String
    , buildVersion : String
    , buildTier : String
    , buildTime : String
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


updateUrl : String -> JustWatchOffer -> JustWatchOffer
updateUrl url offer =
    case offer of
        Flatrate provider _ presentationType ->
            Flatrate provider url presentationType

        Rent provider _ presentationType price ->
            Rent provider url presentationType price

        Buy provider _ presentationType price ->
            Rent provider url presentationType price


type alias JustWatchData =
    { offers : List JustWatchOffer
    , scores : List JustWatchScore
    }



-- BECHDEL


type alias BechdelRating =
    { rating : Int
    , dubious : Bool
    }
