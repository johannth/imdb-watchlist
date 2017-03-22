module Main exposing (..)

import Types exposing (..)
import State
import View
import Navigation
import Api


-- Hot Loading Requires the program to accept flags


main : Program Flags Model Msg
main =
    Navigation.programWithFlags UrlChange
        { init = State.init
        , view = View.rootView
        , update = State.update
        , subscriptions = Api.subscriptions
        }
