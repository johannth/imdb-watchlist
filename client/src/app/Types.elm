module Types exposing (..)

import Table
import Dict
import Http
import Navigation
import Date exposing (Date)
import Set exposing (Set)
import Json.Decode as Decode


type alias Model =
    { apiHost : String
    , imdbUserIdInputCurrentValue : String
    , lists : Dict.Dict String (List String)
    , movies : Dict.Dict String Movie
    , genres : Set String
    , selectedGenres : Set String
    , buildInfo : BuildInfo
    , tableState : Table.State
    }


type Msg
    = Void
    | ImdbUserIdInput String
    | LookupWatchList String
    | ReceivedWatchList String (List Movie)
    | ReceivedMovie Movie
    | ClearList String
    | SetTableState Table.State
    | UrlChange Navigation.Location
    | ToggleGenreFilter String


emptyModel : Flags -> Model
emptyModel flags =
    { apiHost = flags.apiHost
    , imdbUserIdInputCurrentValue = ""
    , lists = Dict.empty
    , movies = Dict.empty
    , genres = Set.empty
    , selectedGenres = Set.empty
    , tableState = Table.initialSort "Priority"
    , buildInfo = BuildInfo flags.buildVersion flags.buildTime flags.buildTier
    }


type MovieType
    = Film
    | Series


movieTypetoString : MovieType -> String
movieTypetoString itemType =
    case itemType of
        Film ->
            "Film"

        Series ->
            "Series"


type alias ViewingOptions =
    { netflix : Maybe JustWatchOffer
    , hbo : Maybe JustWatchOffer
    , itunes : Maybe JustWatchOffer
    , amazon : Maybe JustWatchOffer
    }


type alias Ratings =
    { metascore : Maybe Int
    , rottenTomatoesMeter : Maybe Int
    , imdb : Maybe Int
    , bechdel : Maybe BechdelRating
    }


type alias Movie =
    { id : String
    , title : String
    , imdbUrl : String
    , itemType : MovieType
    , releaseDate : Maybe Date
    , runTime : Maybe Int
    , genres : Set String
    , ratings : Ratings
    , viewingOptions : ViewingOptions
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
