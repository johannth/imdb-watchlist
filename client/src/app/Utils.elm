module Utils exposing (..)

import Json.Decode as Decode


lift2 : (a -> b) -> (a -> c) -> (a -> ( b, c ))
lift2 f g =
    \x -> ( f x, g x )


maybeHasValue : Maybe a -> Bool
maybeHasValue maybeValue =
    case maybeValue of
        Just _ ->
            True

        Nothing ->
            False


decodeToTuple : Decode.Decoder a -> Decode.Decoder b -> Decode.Decoder ( a, b )
decodeToTuple decoderA decoderB =
    Decode.map2 (\x y -> ( x, y ))
        decoderA
        decoderB


map9 : (a -> b -> c -> d -> e -> f -> g -> h -> i -> value) -> Decode.Decoder a -> Decode.Decoder b -> Decode.Decoder c -> Decode.Decoder d -> Decode.Decoder e -> Decode.Decoder f -> Decode.Decoder g -> Decode.Decoder h -> Decode.Decoder i -> Decode.Decoder value
map9 f decoder1 decoder2 decoder3 decoder4 decoder5 decoder6 decoder7 decoder8 decoder9 =
    Decode.map8 (\x1 x2 x3 x4 x5 x6 x7 ( x8, x9 ) -> f x1 x2 x3 x4 x5 x6 x7 x8 x9) decoder1 decoder2 decoder3 decoder4 decoder5 decoder6 decoder7 (decodeToTuple decoder8 decoder9)
