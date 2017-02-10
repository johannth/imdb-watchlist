module Utils exposing (..)


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
