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
    , error : Maybe String
    }


type Msg
    = ImdbUserIdInput String
    | LookupWatchList String
    | ReceivedWatchList String (Result Http.Error (List Movie))
    | ReceivedMovies (Result Http.Error (List Movie))
    | Error String
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
    , error = Nothing
    }


type MovieType
    = Film
    | Series


movieTypeToString : MovieType -> String
movieTypeToString itemType =
    case itemType of
        Film ->
            "Film"

        Series ->
            "Series"


type alias ViewingOptions =
    { netflix : Maybe ViewingOption
    , hbo : Maybe ViewingOption
    , itunes : Maybe ViewingOption
    , amazon : Maybe ViewingOption
    }


type ViewingOptionPresentationType
    = SD
    | HD


type ViewingOptionProvider
    = Amazon
    | ITunes
    | Netflix
    | HBO


type ViewingOption
    = Rent ViewingOptionProvider String ViewingOptionPresentationType Float
    | Buy ViewingOptionProvider String ViewingOptionPresentationType Float
    | Flatrate ViewingOptionProvider String ViewingOptionPresentationType


type alias BechdelRating =
    { rating : Int
    , dubious : Bool
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
