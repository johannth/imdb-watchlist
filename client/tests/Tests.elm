module Tests exposing (..)

import Test exposing (..)
import Expect
import Fuzz exposing (list, int, tuple, string)
import String


all : Test
all =
    describe "Slugify Test Suite"
        [ describe "slugify"
            [ test "should return empty string if passed empty string" <|
                \() ->
                    Expect.equal "" ""
            ]
        ]
