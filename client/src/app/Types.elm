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
