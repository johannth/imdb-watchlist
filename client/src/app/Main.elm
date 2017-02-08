module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import String


-- Hot Loading Requires the program to accept flags


type alias Flags =
    { build_version : String
    , build_tier : String
    , build_time : String
    }


main : Program Flags Model Msg
main =
    Html.programWithFlags
        { init = init
        , view = rootView
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias BuildInfo =
    { version : String
    , time : String
    , tier : String
    }


type alias Model =
    { buildInfo : BuildInfo
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( Model (BuildInfo flags.build_version flags.build_time flags.build_tier)
    , Cmd.none
    )



-- UPDATE


type Msg
    = Default


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Default ->
            ( model
            , Cmd.none
            )



-- VIEW


rootView : Model -> Html Msg
rootView model =
    div [ id "content" ]
        [ h1 [ id "title" ] [ text "Watchlist" ]
        , div [ id "footer" ]
            [ buildInfoView model.buildInfo
            ]
        ]


buildInfoView : BuildInfo -> Html Msg
buildInfoView buildInfo =
    text ("Version: " ++ buildInfo.time ++ " " ++ (String.slice 0 8 buildInfo.version) ++ "-" ++ buildInfo.tier)



-- HTTP
-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
