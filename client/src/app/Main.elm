module Main exposing (..)

import Html exposing (..)
import Types exposing (..)
import State
import View


-- Hot Loading Requires the program to accept flags


main : Program Flags Model Msg
main =
    Html.programWithFlags
        { init = State.init
        , view = View.rootView
        , update = State.update
        , subscriptions = \_ -> Sub.none
        }
