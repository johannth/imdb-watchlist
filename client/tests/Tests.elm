module Tests exposing (..)

import Test exposing (..)
import Expect
import Fuzz exposing (list, int, tuple, string)
import String
import State exposing (..)
import Types exposing (..)


all : Test
all =
    describe "Calculate Priority Test Suite"
        [ describe "defaultPriorityWeights"
            [ test "should sum to 1" <|
                \() ->
                    Expect.equal
                        1
                        (defaultPriorityWeights.runTime
                            + defaultPriorityWeights.metascore
                            + defaultPriorityWeights.tomatoMeter
                            + defaultPriorityWeights.imdbRating
                            + defaultPriorityWeights.bechdel
                        )
            ]
        , describe "normalizeBechdel"
            [ test "should return 0 if bechdel rating is 0 and not dubious" <|
                \() ->
                    Expect.equal 0 (normalizeBechdel (BechdelRating 0 False))
            , test "should return 33 if bechdel rating is 2 and not dubious" <|
                \() ->
                    Expect.equal 33 (normalizeBechdel (BechdelRating 1 False))
            , test "should return 67 if bechdel rating is 2 and not dubious" <|
                \() ->
                    Expect.equal 67 (normalizeBechdel (BechdelRating 2 False))
            , test "should return 100 if bechdel rating is 3 and not dubious" <|
                \() ->
                    Expect.equal 100 (normalizeBechdel (BechdelRating 3 False))
            , test "should return 0 if bechdel rating is 0 and dubious" <|
                \() ->
                    Expect.equal 0 (normalizeBechdel (BechdelRating 0 True))
            , test "should return 17 if bechdel rating is 1 and dubious" <|
                \() ->
                    Expect.equal 17 (normalizeBechdel (BechdelRating 1 True))
            , test "should return 50 if bechdel rating is 2 and dubious" <|
                \() ->
                    Expect.equal 50 (normalizeBechdel (BechdelRating 2 True))
            , test "should return 83 if bechdel rating is 3 and dubious" <|
                \() ->
                    Expect.equal 83 (normalizeBechdel (BechdelRating 3 True))
            ]
        , describe "normalizeRunTime"
            [ test "should return 100 if runTime is 0 minutes" <|
                \() ->
                    Expect.equal 100 (normalizeRunTime 0)
            , test "should return almost 0 if runTime is very high" <|
                \() ->
                    Expect.lessThan 0.001 (normalizeRunTime 100000000)
            , test "should return 50 if runTime is 120 minutes" <|
                \() ->
                    Expect.equal 50 (normalizeRunTime 120)
            , test "should return 64 if runTime is 90 minutes" <|
                \() ->
                    Expect.equal 64 (normalizeRunTime 90)
            , test "should return 80 if runTime is 60 minutes" <|
                \() ->
                    Expect.equal 80 (normalizeRunTime 60)
            , test "should return ~94 if runTime is 30 minutes" <|
                \() ->
                    Expect.equal 94 (round (normalizeRunTime 30))
            ]
        ]
